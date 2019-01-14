
resource "aws_security_group" "default" {
  name = "app_default_sg-${random_id.clusterid.hex}"
  description = "Default security group that allows inbound and outbound traffic from all instances in the VPC"
  vpc_id = "${aws_vpc.app_vpc.id}"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["${aws_vpc.app_vpc.cidr_block}"]
    self        = true
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  lifecycle  {
    create_before_destroy = true
  }

  tags = "${merge(
    var.default_tags,
    map("Name", "app-default-sg-${random_id.clusterid.hex}"),
    map("app/cluster/${random_id.clusterid.hex}", "${random_id.clusterid.hex}")
  )}"
}

resource "aws_security_group_rule" "bastion-22-ingress" {
  count = "${var.bastion["nodes"] > 0 ? length(var.allowed_cidr_bastion_22) : 0}"
  type = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [
    "${element(var.allowed_cidr_bastion_22, count.index)}"
  ]
  lifecycle  {
    create_before_destroy = true
  }
  security_group_id = "${aws_security_group.bastion.id}"
}

resource "aws_security_group_rule" "bastion-22-egress" {
  count = "${var.bastion["nodes"] > 0 ? 1 : 0}"
  type = "egress"
  from_port   = "0"
  to_port     = "0"
  protocol    = "-1"
  cidr_blocks = [
    "0.0.0.0/0"
  ]

  lifecycle  {
    create_before_destroy = true
  }

  security_group_id = "${aws_security_group.bastion.id}"
}

resource "aws_security_group" "bastion" {
  count = "${var.bastion["nodes"] > 0 ? 1 : 0}"
  name = "app-bastion-${random_id.clusterid.hex}"
  description = "allow SSH"
  vpc_id = "${aws_vpc.app_vpc.id}"

  lifecycle  {
    create_before_destroy = true
  }

  tags = "${merge(
    var.default_tags,
    map("Name", "app-bastion-${random_id.clusterid.hex}")
  )}"
}

resource "aws_security_group" "proxy" {
  name = "app-proxy-${random_id.clusterid.hex}"
  description = "app ${random_id.clusterid.hex} proxy nodes"
  vpc_id = "${aws_vpc.app_vpc.id}"

  lifecycle  {
    create_before_destroy = true
  }

  tags = "${merge(
    var.default_tags,
    map("Name", "app-proxy-${random_id.clusterid.hex}")
  )}"
}

resource "aws_security_group_rule" "proxy-egress" {
  type = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = [
    "0.0.0.0/0"
  ]

  lifecycle  {
    create_before_destroy = true
  }

  security_group_id = "${aws_security_group.proxy.id}"
}

resource "aws_security_group_rule" "proxy-8443-ngw" {
    count = "${length(var.azs)}"
    type = "ingress"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["${element(aws_eip.app_ngw_eip.*.public_ip, count.index)}/32"]
    security_group_id = "${aws_security_group.proxy.id}"

    lifecycle  {
      create_before_destroy = true
    }

    description = "allow app to contact itself on console endpoint over the nat gateway"
}

resource "aws_security_group_rule" "proxy-8443-ingress" {
  count = "${length(var.allowed_cidr_proxy_8443)}"
  type = "ingress"
  from_port   = 8443
  to_port     = 8443
  protocol    = "tcp"
  cidr_blocks = [
    "${element(var.allowed_cidr_proxy_8443, count.index)}"
  ]

  lifecycle  {
    create_before_destroy = true
  }
  
  security_group_id = "${aws_security_group.proxy.id}"
}
