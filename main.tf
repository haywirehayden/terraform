provider "aws" {
  profile = "default"
  region     = "eu-west-2"
}

resource "aws_instance" "demo1" {
    ami = var.ami
    instance_type = var.instance_type
    key_name = "TF_key"
    vpc_security_group_ids = [aws_security_group.allow_ssh.id]

    tags = {
        project = var.project_name
    }

    depends_on = [aws_key_pair.TF_key]
}

resource "aws_s3_bucket" "sarahsbucket2" {
    bucket = var.s3_bucket_name
}

resource "aws_security_group" "allow_ssh" {
    name = var.security_group_name
    description = "allow ssh access"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        project = var.project_name
    }
}

resource "aws_key_pair" "TF_key" {
    key_name = "TF_key"
    public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "local_file" "TF_key" {
    content = tls_private_key.rsa.private_key_pem
    filename = "tf_key"
}

resource "aws_instance" "my_rds" {
    vpc_security_group_ids  = [aws_security_group.ec2-rds.id]
    ami                     = "ami-0fb391cce7a602d1f"
    instance_type           = "t2.micro"
    key_name                = "TF_key"
    user_data_replace_on_change = true
        user_data =<<-EOF
            #!/bin/bash
            sudo apt-get update -y
            sudo apt install mysql-client -y
            EOF
}
resource "aws_security_group" "rds-ec2"{
    name = "rds-ecs_security_group"
    description = "security group for rds"
}

resource "aws_security_group" "ec2-rds" {
    name = "ec2-rds_security_group_name"
    description = "security group for ec2"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

      egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
  }

}

resource "aws_security_group_rule" "ec2-rds" {
    security_group_id        = aws_security_group.ec2-rds.id
    type                     = "egress"
    from_port                = 3306
    to_port                  = 3306
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.rds-ec2.id
}

resource "aws_security_group_rule" "rds-ec2" {
    type = "ingress"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_group_id = aws_security_group.rds-ec2.id
    source_security_group_id = aws_security_group.ec2-rds.id
}

resource "aws_db_subnet_group" "subnet_group" {
  name       = "my-subnet-group"
  subnet_ids = ["subnet-0ff32d1212f4d5611", "subnet-0700c5f4272bb3d37", "subnet-0ae219547f478de9d"]
}


resource "aws_db_instance" "dbinstance" {
    db_subnet_group_name = aws_db_subnet_group.subnet_group.name
    vpc_security_group_ids = [aws_security_group.ec2-rds.id]
    engine = "mysql"
    engine_version = "8.0.35"
    allocated_storage = 20
    storage_type = "gp2"
    username = "test"
    password = "password123"
    backup_retention_period = 0 
    skip_final_snapshot = true 
    publicly_accessible = false
    instance_class = "db.t3.micro" 
}

#resource "local_file" "Key2" {
#    filename = "Key2"
#    content = tls_private_key.rsa.private_key_pem
#    file_permission = 400
#}

output "vm_public_ip" {
    value = aws_instance.demo1.public_ip
}

output "s3_bucket_domain" {
    value = aws_s3_bucket.sarahsbucket2.bucket_domain_name
}

output "public_key" {
    value = aws_instance.demo1.public_ip
}

output "ec2_public_ip_for_mysql" {
  value = aws_instance.my_rds.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.dbinstance.endpoint
}
