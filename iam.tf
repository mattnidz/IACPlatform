
## IAM EC2 role for adding policies later on.
resource "aws_iam_role" "app_ec2_iam_role" {
  count = "${var.existing_ec2_iam_instance_profile_name == "" ? 1 : 0}"
  name = "${var.ec2_iam_role_name}-${random_id.clusterid.hex}"
  lifecycle  {
      create_before_destroy = true
    }
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

## Enables attaching/detaching volumes.
resource "aws_iam_role_policy" "app_ec2_iam_role_policy" {
  count = "${var.existing_ec2_iam_instance_profile_name == "" ? 1 : 0}"
  name = "${var.ec2_iam_role_name}-policy-${random_id.clusterid.hex}"
  role = "${aws_iam_role.app_ec2_iam_role.id}"
  lifecycle  {
      create_before_destroy = true
    }
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:AttachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DetachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:*"],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": ["elasticloadbalancing:*"],
      "Resource": ["*"]
    }
  ]
}
EOF
}

# Needed for saving backups or configs to s3.
resource "aws_iam_role_policy_attachment" "app_iam_s3fullaccess" {
  count = "${var.existing_ec2_iam_instance_profile_name == "" ? 1 : 0}"
  role = "${aws_iam_role.app_ec2_iam_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "app_ec2_instance_profile" {
  count = "${var.existing_ec2_iam_instance_profile_name == "" ? 1 : 0}"
  name = "${var.ec2_iam_role_name}-instance-profile-${random_id.clusterid.hex}"
  role = "${aws_iam_role.app_ec2_iam_role.name}"
  lifecycle  {
      create_before_destroy = true
    }
}