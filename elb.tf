# locals  {
#   proxy_node_ids = "${compact(concat(aws_instance.appproxy.*.id, aws_instance.appproxy.*.id))}"
# }


## Network LoadBalancer which will allow loadbalancing between availabilty zones.
resource "aws_lb" "app-console" {
  depends_on = [
    "aws_internet_gateway.app_gw"
  ]

  name = "app-console"
  load_balancer_type = "network"
  #  internal = "true"

  lifecycle  {
    create_before_destroy = true
  }

  tags = "${var.default_tags}"

  # The same availability zone as our instance
  subnets = [ "${aws_subnet.app_public_subnet.*.id}" ]
}


resource "aws_lb_target_group" "app-console-8443" {
  name = "app-${random_id.clusterid.hex}-console-8443-tg"
  port = 8443
  protocol = "TCP"
  tags = "${var.default_tags}"
  vpc_id = "${aws_vpc.app_vpc.id}"

  lifecycle  {
    create_before_destroy = false
  }

}

## Autoscaling Attachment
resource "aws_autoscaling_attachment" "console-8443" {
  alb_target_group_arn  = "${aws_lb_target_group.app-console-8443.arn}"
  autoscaling_group_name = "${aws_autoscaling_group.proxy.id}"
}

resource "aws_lb_target_group_attachment" "console-8443" {
  count = "${var.proxy["nodes"]}"
  target_group_arn = "${aws_lb_target_group.app-console-8443.arn}"
  target_id = "${element(aws_instance.appproxy.*.id, count.index)}"
  # target_id = "${element(aws_network_interface.proxyvip.*.id, count.index)}"
  port = 8443
  lifecycle  {
    create_before_destroy = false
  }

}

#TODO: Add healthcheck once web application is more matured.
resource "aws_lb_listener" "app-console-8443" {
  load_balancer_arn = "${aws_lb.app-console.arn}"
  port = "8443"
  protocol = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.app-console-8443.arn}"
    type = "forward"
  }

  lifecycle  {
    create_before_destroy = false
  }
}

