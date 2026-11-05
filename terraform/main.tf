# ---------- Your IP (so only you can reach the app) ----------
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

# ---------- Latest Amazon Linux 2023 AMI ----------
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------- Network ----------
resource "aws_vpc" "lab" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "lab-vpc" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "lab-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "lab-public-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
  tags = { Name = "lab-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name   = "lab-app-sg"
  vpc_id = aws_vpc.lab.id

  ingress {
    description = "Juice Shop - my IP only"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.my_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- IAM role (INTENTIONALLY over-permissioned) ----------
resource "aws_iam_role" "app" {
  name = "lab-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Lets you connect to the server through AWS Session Manager - no SSH keys needed
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# VULN-1: wildcard S3 access on every bucket in the account
resource "aws_iam_role_policy" "overpermissive" {
  name = "lab-app-overpermissive"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "VulnS3Wildcard"
      Effect   = "Allow"
      Action   = "s3:*"
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "lab-app-profile"
  role = aws_iam_role.app.name
}

# ---------- S3 bucket with FAKE sensitive data ----------
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "data" {
  bucket        = "lab-customer-data-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_object" "fake_pii" {
  bucket  = aws_s3_bucket.data.id
  key     = "exports/customers.csv"
  content = <<-EOT
    customer_id,name,email,card_last4
    1001,Jane Doe,jane.doe@example.com,4242
    1002,John Roe,john.roe@example.com,1881
    1003,Alex Poe,alex.poe@example.com,9034
  EOT
}

# ---------- The server running Juice Shop ----------
resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023.insecure_value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  # VULN-2: IMDSv1 allowed (no session token required)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
    encrypted   = true
  }

    user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y docker
    systemctl enable --now docker
    docker run -d --restart unless-stopped -p 80:3000 --name juice-shop bkimminich/juice-shop
  EOF

  tags = { Name = "lab-juice-shop" }
}