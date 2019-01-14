resource "aws_vpc" "app_vpc" {
  cidr_block = "${ var.cidr }"
  enable_dns_support = true
  enable_dns_hostnames = true

  lifecycle  {
      create_before_destroy = true
  }

  tags = "${merge(
    var.default_tags, map(
      "Name", "${var.vpcname}-${random_id.clusterid.hex}"
    ),
    map("app/cluster/${random_id.clusterid.hex}", "${random_id.clusterid.hex}")
  )}"
}

resource "aws_internet_gateway" "app_gw" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  lifecycle  {
      create_before_destroy = true
  }

  tags = "${merge(
    var.default_tags,
    map("Name", "${var.vpcname}-${random_id.clusterid.hex}-InternetGateway"),
    map("app/cluster/${random_id.clusterid.hex}", "${random_id.clusterid.hex}")
  )}"
}

# Create private subnet in each AZ for the worker nodes to recide in
resource "aws_subnet" "app_private_subnet" {
  count                   = "${length(var.azs)}"
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${element(var.subnet_cidrs, count.index)}"
  availability_zone       = "${format("%s%s", element(list(var.aws_region), count.index), element(var.azs, count.index))}"
  
  lifecycle  {
      create_before_destroy = true
  }

  tags = "${merge(
    var.default_tags,
    map("Name", "${format("${var.subnetname}-${random_id.clusterid.hex}-priv-%1d", count.index + 1) }"),
    map("app/cluster/${random_id.clusterid.hex}", "${random_id.clusterid.hex}")
  )}"
}

# Create public subnet in each AZ for the proxy and management nodes to recide in
resource "aws_subnet" "app_public_subnet" {
  count                   = "${length(var.azs)}"
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${element(var.pub_subnet_cidrs, count.index)}"
  availability_zone       = "${format("%s%s", element(list(var.aws_region), count.index), element(var.azs, count.index))}"
  
  lifecycle  {
      create_before_destroy = true
  }

  tags = "${merge(
    var.default_tags,
    map("Name", "${format("${var.subnetname}-${random_id.clusterid.hex}-pub-%1d", count.index + 1) }"),
    map("app/cluster/${random_id.clusterid.hex}", "${random_id.clusterid.hex}")
  )}"
}

# Create Elastic IP for NAT gateway in each AZ
resource "aws_eip" "app_ngw_eip" {
  count = "${length(var.azs)}"

  lifecycle  {
      create_before_destroy = true
  }

  tags = "${merge(
    var.default_tags,
    map("Name", "${format("${var.subnetname}-${random_id.clusterid.hex}-ngw-eip-%1d", count.index + 1)}"),
    map("app/cluster/${random_id.clusterid.hex}", "${random_id.clusterid.hex}")
  )}"
}

# Create NAT gateways for the private networks in each AZ
resource "aws_nat_gateway" "app_nat_gateway" {
  count                   = "${length(var.azs)}"
  allocation_id           = "${element(aws_eip.app_ngw_eip.*.id, count.index)}"
  subnet_id               = "${element(aws_subnet.app_public_subnet.*.id, count.index)}"

  lifecycle  {
      create_before_destroy = true
  }

  tags = "${merge(
    var.default_tags, map(
      "Name", "${format("${var.vpcname}-${random_id.clusterid.hex}-nat-gw-%1d", count.index + 1)}"
    ),
    map("app/cluster/${random_id.clusterid.hex}", "${random_id.clusterid.hex}")
  )}"

  depends_on = ["aws_internet_gateway.app_gw"]
}

resource "aws_route_table" "app_priv_net_route" {
  count = "${length(var.azs)}"
  vpc_id = "${aws_vpc.app_vpc.id}"

  lifecycle  {
      create_before_destroy = true
  }

#  route {
#    cidr_block = "${var.cidr}"
#    gateway_id = "${aws_internet_gateway.app_gw.id}"
#  }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.app_nat_gateway.*.id, count.index)}"
  }

  tags = "${merge(
    var.default_tags, map(
      "Name", "${format("${var.vpcname}-${random_id.clusterid.hex}-main-rtbl-%1d", count.index + 1)}"
    ),
    map("app/cluster/${random_id.clusterid.hex}", "${random_id.clusterid.hex}")
  )}"
}

resource "aws_route_table_association" "a" {
  count          = "${length(var.azs)}"
  subnet_id      = "${element(aws_subnet.app_private_subnet.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.app_priv_net_route.*.id, count.index)}"
  lifecycle  {
      create_before_destroy = true
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.app_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.app_gw.id}"
  lifecycle  {
      create_before_destroy = true
    }
}

# private S3 endpoint
data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}

data "aws_vpc_endpoint_service" "ec2" {
  service = "ec2"
}

resource "aws_vpc_endpoint" "private_s3" {
  vpc_id       = "${aws_vpc.app_vpc.id}"
  service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
  lifecycle  {
      create_before_destroy = true
    }
}

resource "aws_vpc_endpoint" "private_ec2" {
  vpc_id       = "${aws_vpc.app_vpc.id}"
  service_name = "${data.aws_vpc_endpoint_service.ec2.service_name}"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  
  lifecycle  {
      create_before_destroy = true
  }

  security_group_ids = [
    "${aws_security_group.default.id}"
  ]

  subnet_ids = [
    "${aws_subnet.app_private_subnet.*.id}"
  ]
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count = "${length(var.azs)}"
  vpc_endpoint_id = "${aws_vpc_endpoint.private_s3.id}"
  route_table_id  = "${element(aws_route_table.app_priv_net_route.*.id, count.index)}"
  
  lifecycle  {
      create_before_destroy = true
    }
  
}