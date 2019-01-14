resource "aws_route53_zone" "app_private" {
  name = "${random_id.clusterid.hex}.${var.private_domain}"
  vpc_id = "${aws_vpc.app_vpc.id}"
  # force_destroy = "true"
  lifecycle  {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "proxy" {
  // same number of records as instances
  count         = "${var.proxy["nodes"]}"
  zone_id       = "${aws_route53_zone.app_private.zone_id}"
  name = "${format("${var.instance_name}-proxy%02d", count.index + 1) }"
  type = "A"
  ttl = "300"
  // matches up record N to instance N
  records = ["${element(aws_instance.appproxy.*.private_ip, count.index)}"]
  //records = ["${element(aws_network_interface.proxyvip.*.private_ip, count.index)}"]
  lifecycle  {
    create_before_destroy = true
  }
}


