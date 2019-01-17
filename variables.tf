variable "aws_region" {
    default = "us-west-1"
}

variable "owner" {
    default = "unknown"
}

variable "environment" {
    default = "dev"
}

// VPC variables
variable "cidr" {
    default = "10.0.0.0/16"
}

variable "azs" {
    type = "list"
    default = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "private_subnets" {
    type = "list"
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
    type = "list"
    default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "database_subnets" {
    type = "list"
    default = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
}

// Security Groups variables
variable "web_server_cidr_blocks" {
    type = "list"
    default = ["172.31.81.68/32", "212.224.118.16/32", "46.229.218.0/24", "83.228.108.0/24", "86.57.255.92/32", "86.57.255.91/32", "94.26.57.152/32"]
}

// EC2 variables
variable "ami_instance_type_nd" {
    default = "t2.small"
}

variable "ami_instance_type_ce" {
    default = "t2.medium"
}

variable "public_key_path" {
    description = "Path to public ssh key"
    default     = "~/.ssh/id_rsa.pub"
}

varible "domain" {
    description = "Domain Name"
    default = "compbio-stage.percayai.com"
}

variable "user_data" {
    default = <<-EOF
                #!/bin/bash
                APP_CONTAINER=compbio_back
                APP_IMAGE=834951890310.dkr.ecr.us-east-1.amazonaws.com/compbio
                AWS_DEFAULT_REGION=us-west-1
                DB=compbio-stage.clcdt8sugzbd.us-west-1.rds.amazonaws.com
                PORT=5000
                echo "install CodeDeploy"
                sudo yum -y update
                sudo yum install -y ruby
                cd /home/ec2-user
                wget https://aws-codedeploy-us-west-1.s3.amazonaws.com/latest/install
                chmod +x ./install
                sudo ./install auto
                docker stop $APP_CONTAINER
                $(aws ecr get-login --region ${AWS_DEFAULT_REGION} --no-include-email)
                docker pull $APP_IMAGE:latest
                docker pull $APP_IMAGE:latest
                    --env ADMIN_EMAIL="Nikita_Agafonov@epam.com;bill.langton@gmail.com;maksim_lyskou@epam.com" \
                    --env API_PORT=5000 \
                    --env DB_URI="postgres://root:${DB_PASSWORD}@${DB}/compbiodb" \
                    -v /efs/logs:/logs \
                    -v /efs/projects:/projects \
                    -v /config:/config \
                    $APP_IMAGE:latest
                sudo mkdir /etc/ssl/private/
                sudo aws s3 cp  s3://compbiovis-codedeploy/STAR.percayai.com.pem /etc/ssl/certs/STAR.percayai.com.pem
                sudo aws s3 cp  s3://compbiovis-codedeploy/STAR.percayai.com_private.pem /etc/ssl/private/STAR.percayai.com_private.pem
                sudo aws s3 cp s3://compbiovis-codedeploy/nginx.conf /etc/nginx/nginx.conf
                sudo systemctl restart nginx
                EOF
}

// RDS variables
variable "identifier" {
    default = "compbio-stage-rds"
}

variable "engine" {
    default = "postgres"
}

variable "engine_version" {
    default = "10.5"
}

variable "instance_class" {
    default = "db.t2.micro"
}

variable "allocated_storage" {
    default = "20"
}

variable "storage_encrypted" {
    default = false
}

variable "name" {
    default = "compbiostage"
}

variable "username" {
    default = "root"
}

variable "password" {
    default = "YourPwdShouldBeLongAndSecure!"
}

variable "port" {
    default = "5432"
}

variable "maintenance_window" {
    default = "Mon:00:00-Mon:03:00"
}

variable "backup_window" {
    default = "03:00-06:00"
}

variable "backup_retention_period" {
    default = 0
}
