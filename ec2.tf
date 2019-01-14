## Generate a new key if this is required for deployment to prevents resource collisions
resource "random_id" "clusterid" {
  byte_length = "2"
}

locals  {
  iam_ec2_instance_profile_id = "${var.existing_ec2_iam_instance_profile_name != "" ?
        var.existing_ec2_iam_instance_profile_name :
        element(concat(aws_iam_instance_profile.app_ec2_instance_profile.*.id, list("")), 0)}"

  default_ami = "${var.ami != "" ? var.ami : data.aws_ami.rhel.id}"
}

## Search for RHEL AMI if not provided
data "aws_ami" "rhel" {
  most_recent = true

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["RHEL*7.5_HVM*x86_64*Hourly*GP2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  
  owners = ["309956199498"] # RedHat
}

## Creating ec2 Launch Configuration for AutoScaling
resource "aws_launch_configuration" "proxy" {
  image_id               = "${var.proxy["ami"] != "" ? var.proxy["ami"] : local.default_ami }"
  instance_type = "${var.proxy["type"]}"

  security_groups  = [
    "${aws_security_group.default.id}",
    "${aws_security_group.proxy.id}"
  ]

  root_block_device {
    volume_size = "${var.proxy["disk"]}"
    delete_on_termination = true
  }

  ebs_block_device {
    device_name       = "/dev/xvdx"
    volume_size       = "${var.proxy["app_vol"]}"
    volume_type       = "gp2"
  }

  key_name               = "${var.key_name}"

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- git
- wget
- vim
- dos2unix
rh_subscription:
  enable-repo: rhui-REGION-rhel-server-optional
write_files:
- path: /opt/app/bootstrap-node.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/bootstrap-node.sh"))}
- path: /opt/app/webserver.py
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/webserver.py"))}
- path: /opt/app/index.html
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/index.html"))}
runcmd:
- dos2unix /opt/app/*
- /opt/app/bootstrap-node.sh
users:
- default
- name: appdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
fqdn: ${format("${var.instance_name}-proxy%02d", count.index + 1)}.${random_id.clusterid.hex}.${var.private_domain}
manage_resolv_conf: true
resolv_conf:
  nameservers: [ ${cidrhost(element(aws_subnet.app_private_subnet.*.cidr_block, count.index), 2)}]
  domain: ${random_id.clusterid.hex}.${var.private_domain}
  searchdomains:
  - ${random_id.clusterid.hex}.${var.private_domain}
EOF
}

## Creating AutoScaling Group
resource "aws_autoscaling_group" "proxy" {
  #count                   = "${length(var.azs)}"
  launch_configuration = "${aws_launch_configuration.proxy.id}"
  #availability_zones = ["${format("%s%s", element(list(var.aws_region), count.index), element(var.azs, count.index))}"]
  #availability_zones   = ["${var.azs}"]
  desired_capacity     = "3"
  min_size = 3
  max_size = 3
  min_elb_capacity = "3"
  vpc_zone_identifier = ["${aws_subnet.app_private_subnet.*.id}"]
  #load_balancers = ["${aws_lb.app-console.name}"]
  target_group_arns = ["${aws_lb_target_group.app-console-8443.arn}"]
  
  health_check_type = "EC2"
  tag {
    key = "Name"
    value = "${format("asg-${var.instance_name}-${random_id.clusterid.hex}-proxy%02d", count.index + 1) }"
    propagate_at_launch = true
  }
}

## Bastion ec2 for debugging purposes.
resource "aws_instance" "bastion" {
  count         = "${var.bastion["nodes"]}"
  key_name      = "${var.key_name}"
  ami           = "${var.bastion["ami"] != "" ? var.bastion["ami"] : local.default_ami }"
  instance_type = "${var.bastion["type"]}"
  subnet_id     = "${element(aws_subnet.app_public_subnet.*.id, count.index)}"
  vpc_security_group_ids = [
    "${aws_security_group.default.id}",
    "${aws_security_group.bastion.id}"
  ]

  lifecycle  {
    create_before_destroy = true
  }
  
  availability_zone = "${format("%s%s", element(list(var.aws_region), count.index), element(var.azs, count.index))}"
  associate_public_ip_address = true

  root_block_device {
    volume_size = "${var.bastion["disk"]}"
    delete_on_termination = true
  }

  
  tags = "${merge(var.default_tags, map(
    "Name",  "${format("${var.instance_name}-${random_id.clusterid.hex}-bastion%02d", count.index + 1) }"
  ))}"
  user_data = <<EOF
#cloud-config
fqdn: ${format("${var.instance_name}-bastion%02d", count.index + 1)}.${random_id.clusterid.hex}.${var.private_domain}
users:
- default
manage_resolv_conf: true
resolv_conf:
  nameservers: [ ${cidrhost(element(aws_subnet.app_private_subnet.*.cidr_block, count.index), 2)}]
  domain: ${random_id.clusterid.hex}.${var.private_domain}
  searchdomains:
  - ${random_id.clusterid.hex}.${var.private_domain}
EOF
}

# Application instances which will serve application web portion.
resource "aws_instance" "appproxy" {
  depends_on = [
    "aws_route_table_association.a"
  ]

  count         = "${var.proxy["nodes"]}"
  key_name      = "${var.key_name}"
  ami           = "${var.proxy["ami"] != "" ? var.proxy["ami"] : local.default_ami }"
  instance_type = "${var.proxy["type"]}"

  availability_zone = "${format("%s%s", element(list(var.aws_region), count.index), element(var.azs, count.index))}"

  ebs_optimized = "${var.proxy["ebs_optimized"]}"
  root_block_device {
    volume_size = "${var.proxy["disk"]}"
  }

  ebs_block_device {
    device_name       = "/dev/xvdx"
    volume_size       = "${var.proxy["app_vol"]}"
    volume_type       = "gp2"
  }

  network_interface {
    network_interface_id = "${element(aws_network_interface.proxyvip.*.id, count.index)}"
    device_index = 0
    
  }


  # lifecycle  {
  #   create_before_destroy = true
  # }

  iam_instance_profile = "${local.iam_ec2_instance_profile_id}"

  tags = "${merge(
    var.default_tags,
    map("Name", "${format("${var.instance_name}-${random_id.clusterid.hex}-proxy%02d", count.index + 1) }"),
    map("app/cluster/${random_id.clusterid.hex}", "${random_id.clusterid.hex}")
  )}"
  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- git
- wget
- vim
- dos2unix
rh_subscription:
  enable-repo: rhui-REGION-rhel-server-optional
write_files:
- path: /opt/app/bootstrap-node.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/bootstrap-node.sh"))}
- path: /opt/app/webserver.py
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/webserver.py"))}
- path: /opt/app/index.html
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/index.html"))}
runcmd:
- dos2unix /opt/app/*
- /opt/app/bootstrap-node.sh
users:
- default
- name: appdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
fqdn: ${format("${var.instance_name}-proxy%02d", count.index + 1)}.${random_id.clusterid.hex}.${var.private_domain}
manage_resolv_conf: true
resolv_conf:
  nameservers: [ ${cidrhost(element(aws_subnet.app_private_subnet.*.cidr_block, count.index), 2)}]
  domain: ${random_id.clusterid.hex}.${var.private_domain}
  searchdomains:
  - ${random_id.clusterid.hex}.${var.private_domain}
EOF
}

resource "aws_network_interface" "proxyvip" {
  count           = "${var.proxy["nodes"]}"
  subnet_id       = "${element(aws_subnet.app_private_subnet.*.id, count.index)}"
  private_ips_count = 1
  

  lifecycle  {
    create_before_destroy = true
  }

  #  attachment {
  #   instance     = "${aws_instance.appproxy.id}"
  #   device_index = 0
  # }

  security_groups = [
    "${aws_security_group.default.id}",
    "${aws_security_group.proxy.id}"
  ]

  tags = "${merge(var.default_tags, map(
    "Name", "${format("${var.instance_name}-${random_id.clusterid.hex}-proxy%02d", count.index + 1) }"
  ))}"
}

# resource "aws_network_interface_attachment" "proxyvip" {
  
#   instance_id = "${format("${var.instance_name}-${random_id.clusterid.hex}-proxy%02d", count.index + 1) }"
#   network_interface_id = "${element(aws_network_interface.proxyvip.*.id, count.index)}"
#   device_index = 0
#   lifecycle  {
#     create_before_destroy = true
#   }
# }


output "App Console External URL" {
  value = "http://${var.user_provided_cert_dns != "" ? var.user_provided_cert_dns : aws_lb.app-console.dns_name}:8443"
}
