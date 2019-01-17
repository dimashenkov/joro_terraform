# Configure the AWS Provider
provider "aws" {
    region     = "${var.aws_region}"
}

#####
# VPC
#####
module "vpc" {
    source = "./modules/vpc"

    name = "unknown"

    cidr = "${var.cidr}"

    azs             = "${var.azs}"
    private_subnets = "${var.private_subnets}"
    public_subnets  = "${var.public_subnets}"
    database_subnets    = "${var.database_subnets}"

    enable_nat_gateway = true
    single_nat_gateway = true

    tags = {
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }

    vpc_tags = {
        Name = "${var.owner}-vpc"
    }
}

#####
# Security Groups
#####
module "dev-web-sg" {
    source = "./modules/security-group"

    name        = "dev-web-sg"
    description = "Security group for web server"
    vpc_id      = "${module.vpc.vpc_id}"

    tags = {
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }

    ingress_cidr_blocks = ["0.0.0.0/0"]
    egress_cidr_blocks = ["0.0.0.0/0"]
    ingress_rules = ["https-443-tcp"]
    egress_rules = ["all-all"]
    ingress_with_cidr_blocks = [
        {
            from_port   = 22
            to_port     = 22
            protocol    = "tcp"
            cidr_blocks = "${join(",", var.web_server_cidr_blocks)}"
        }
    ]
}

module "stage-ce-sg" {
    source = "./modules/security-group"

    name        = "stage-ce-sg"
    description = "Allow access from CE to 5000"
    vpc_id      = "${module.vpc.vpc_id}"

    tags = {
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }

    egress_cidr_blocks = ["0.0.0.0/0"]
    ingress_with_cidr_blocks = [
        {
            from_port   = 22
            to_port     = 22
            protocol    = "tcp"
            cidr_blocks = "172.31.4.231/32"
        }
    ]
    egress_rules = ["all-all"]
}

module "stage-rds-sg" {
    source = "./modules/security-group"

    name        = "stage-rds-sg"
    description = "Allow access from Docker EC2 to RDS port 5432"
    vpc_id      = "${module.vpc.vpc_id}"

    tags = {
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }

    number_of_computed_ingress_with_source_security_group_id = 1
    computed_ingress_with_source_security_group_id = [
        {
            rule                     = "postgresql-tcp"
            source_security_group_id = "${module.dev-web-sg.this_security_group_id}"
        }
    ]
    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]
}

module "dev-bitbucket-ssh-sg" {
    source = "./modules/security-group"

    name        = "dev-bitbucket-ssh-sg"
    description = "Allow access from BitBucket Pipeline over ssh"
    vpc_id      = "${module.vpc.vpc_id}"

    tags = {
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }

    ingress_cidr_blocks = ["0.0.0.0/0"]
    egress_cidr_blocks = ["0.0.0.0/0"]
    ingress_rules = ["ssh-tcp"]
    egress_rules = ["all-all"]
}

module "efs-sg" {
    source = "./modules/security-group"

    name        = "efs-mnt-sg"
    description = "Allow NFS traffic for instances in the VPC"
    vpc_id      = "${module.vpc.vpc_id}"

    tags = {
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }

    ingress_cidr_blocks = ["${module.vpc.vpc_cidr_block}"]
    egress_cidr_blocks = ["${module.vpc.vpc_cidr_block}"]
    ingress_rules = ["nfs-tcp"]
    egress_rules = ["nfs-tcp"]
}

#####
# efs
#####
resource "aws_efs_file_system" "main" {

    tags = {
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }
}

resource "aws_efs_mount_target" "main" {
    count = "${length(module.vpc.public_subnets)}"

    file_system_id = "${aws_efs_file_system.main.id}"
    subnet_id      = "${element(module.vpc.public_subnets, count.index)}"

    security_groups = [
      "${module.efs-sg.this_security_group_id}",
    ]
}
#####
# EC2
#####
data "aws_ami" "nginx-docker" {
    most_recent = true
    filter {
        name = "name"
        values = ["packer-nginx-docker*"]
    }
}

data "aws_ami" "ce-instance-ami" {
    most_recent = true
    filter {
        name = "name"
        values = ["packer-ce-server-*"]
    }
}

resource "aws_iam_role_policy" "ec2-role-policy" {
  name = "ec2-role-policy"
  role = "${aws_iam_role.ec2_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
        {
            "Action": [
                "sqs:*",
                "s3:*",
                "ses:*",
                "s3:*",
                "dbqms:CreateFavoriteQuery",
                "dbqms:DescribeFavoriteQueries",
                "dbqms:UpdateFavoriteQuery",
                "dbqms:DeleteFavoriteQueries",
                "dbqms:GetQueryString",
                "dbqms:CreateQueryHistory",
                "dbqms:DescribeQueryHistory",
                "dbqms:UpdateQueryHistory",
                "dbqms:DeleteQueryHistory",
                "dbqms:DescribeQueryHistory",
                "rds-data:ExecuteSql",
                "secretsmanager:CreateSecret",
                "secretsmanager:ListSecrets",
                "secretsmanager:GetRandomPassword",
                "tag:GetResources",
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeNetworkInterfaceAttribute",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcs",
                "ec2:ModifyNetworkInterfaceAttribute",
                "elasticfilesystem:*",
                "kms:DescribeKey",
                "kms:ListAliases",
                "ecr:*",
                "cloudtrail:LookupEvents"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = "${aws_iam_role.ec2_role.name}"
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = <<EOF

  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_key_pair" "main" {
    key_name = "code-deploy-demo"
    public_key = "${file(var.public_key_path)}"
}

module "nginx-docker" {
    source = "./modules/ec2-instance"

    instance_count = 1

    name                        = "nginx-docker"
    ami                         = "${data.aws_ami.nginx-docker.id}"
    instance_type               = "${var.ami_instance_type_nd}"
    user_data                   = "${var.user_data}"
    subnet_id                   = "${element(module.vpc.public_subnets, 0)}"
    key_name                    = "${aws_key_pair.main.key_name}"
    vpc_security_group_ids      = ["${module.dev-web-sg.this_security_group_id}"]
    iam_instance_profile        = "${aws_iam_instance_profile.ec2_instance_profile.name}"
    associate_public_ip_address = true

    tags = {
        Name        = "nginx-docker"
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }
}

resource "aws_route53_record" "combio-stage" {
    zone_id = "Z1DMY778T9APL7"
    name    = "${var.domain}"
    type    = "A"
    ttl     = "300"
    records = ["${module.nginx-docker.public_ip}"]
}


module "ce-instance" {
    source = "./modules/ec2-instance"

    instance_count = 1

    name                        = "ce-instance"
    ami                         = "${data.aws_ami.ce-instance-ami.id}"
    instance_type               = "${var.ami_instance_type_ce}"
    user_data                   = "${var.user_data}"
    subnet_id                   = "${element(module.vpc.public_subnets, 0)}"
    key_name                    = "${aws_key_pair.main.key_name}"
    vpc_security_group_ids      = ["${module.dev-web-sg.this_security_group_id}"]
    associate_public_ip_address = true

    tags = {
        Name        = "ce-instance-${var.environment}"
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }
}

#####
# RDS
#####
module "db" {
    source = "./modules/rds"

    identifier = "${var.identifier}"

    engine            = "${var.engine}"
    engine_version    = "${var.engine_version}"
    instance_class    = "${var.instance_class}"
    allocated_storage = "${var.allocated_storage}"
    storage_encrypted = "${var.storage_encrypted}"
    name = "${var.name}"
    username = "${var.username}"
    password = "${var.password}"
    port     = "${var.port}"
    vpc_security_group_ids = ["${module.stage-rds-sg.this_security_group_id}"]
    maintenance_window = "${var.maintenance_window}"
    backup_window      = "${var.backup_window}"
    backup_retention_period = "${var.backup_retention_period}"

    tags = {
        Name        = "ce-rds-${var.environment}"
        Owner       = "${var.owner}"
        Environment = "${var.environment}"
    }

    # DB subnet group
    subnet_ids = ["${module.vpc.database_subnets}"]
}
