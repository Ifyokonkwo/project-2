locals {
  name           = "proj"
  db_cred        = jsondecode(aws_secretsmanager_secret_version.rds_credentials_version.secret_string)
  new_relic_cred = jsondecode(aws_secretsmanager_secret_version.rds_credentials_version.secret_string)
}

############################################
# VPC (Network Foundation)
############################################
resource "aws_vpc" "proj_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${local.name}-vpc"
  }
}
############################################
# PUBLIC SUBNETS
############################################
resource "aws_subnet" "proj_pubsub_1" {
  vpc_id            = aws_vpc.proj_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  tags              = { Name = "${local.name}-public-1" }
}
resource "aws_subnet" "proj_pubsub_2" {
  vpc_id            = aws_vpc.proj_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
  tags              = { Name = "${local.name}-public-2" }
}
############################################
# PRIVATE SUBNETS
############################################
resource "aws_subnet" "proj_prisub_1" {
  vpc_id            = aws_vpc.proj_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-1a"
  tags              = { Name = "${local.name}-private-1" }
}
resource "aws_subnet" "proj_prisub_2" {
  vpc_id            = aws_vpc.proj_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-1b"
  tags              = { Name = "${local.name}-private-2" }
}
############################################
# INTERNET GATEWAY
############################################
resource "aws_internet_gateway" "proj_igw" {
  vpc_id = aws_vpc.proj_vpc.id
  tags   = { Name = "${local.name}-igw" }
}
############################################
# ELASTIC IP FOR NAT GATEWAY
############################################
resource "aws_eip" "proj_eip" {
  domain = "vpc"
  tags = {
    Name = "${local.name}-eip"
  }
}
############################################
# NAT GATEWAY (PRIVATE INTERNET ACCESS)
############################################
resource "aws_nat_gateway" "proj_nat" {
  allocation_id = aws_eip.proj_eip.id
  subnet_id     = aws_subnet.proj_pubsub_1.id
  tags          = { Name = "${local.name}-nat" }
}
############################################
# ROUTE TABLES
############################################
# Public Route Table
resource "aws_route_table" "proj_pub_rt" {
  vpc_id = aws_vpc.proj_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.proj_igw.id
  }
}
# Private Route Table
resource "aws_route_table" "proj_pri_rt" {
  vpc_id = aws_vpc.proj_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.proj_nat.id
  }
}
############################################
# connecting subnets to route tables
############################################
resource "aws_route_table_association" "proj_pubsub_1_rt" {
  subnet_id      = aws_subnet.proj_pubsub_1.id
  route_table_id = aws_route_table.proj_pub_rt.id
}
resource "aws_route_table_association" "proj_pubsub_2_rt" {
  subnet_id      = aws_subnet.proj_pubsub_2.id
  route_table_id = aws_route_table.proj_pub_rt.id
}
resource "aws_route_table_association" "proj_prisub_1_rt" {
  subnet_id      = aws_subnet.proj_prisub_1.id
  route_table_id = aws_route_table.proj_pri_rt.id
}
resource "aws_route_table_association" "jppt2_prisub_2_rt" {
  subnet_id      = aws_subnet.proj_prisub_2.id
  route_table_id = aws_route_table.proj_pri_rt.id
}

############################################
# KEY PAIR
############################################
resource "tls_private_key" "proj_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "proj_key" {
  key_name   = "${local.name}-key"
  public_key = tls_private_key.proj_key.public_key_openssh
}
resource "local_file" "proj_private_key" {
  content         = tls_private_key.proj_key.private_key_pem
  filename        = "${path.module}/${local.name}-key.pem" # Save the private key to a file in the current module directory
  file_permission = "400"
}
############################################
# creating ubuntu ami
############################################
data "aws_ami" "ubuntu" {
  most_recent = true             ## selects the newest matching AMI
  owners      = ["099720109477"] # Canonical (Ubuntu) only looks for AMIs published by Canonical (official Ubuntu owner)
  filter {
    name   = "name" # searches for Ubuntu 22.04 Jammy images
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"] # ensures the AMI uses HVM (Hardware Virtual Machine) virtualization
  }
}
############################################
# creating Redhat ami
############################################
data "aws_ami" "rhel" {
  most_recent = true             # selects the newest matching AMI
  owners      = ["309956199498"] # search to AMIs published by the official Red Hat AWS account.
  filter {
    name   = "name"
    values = ["RHEL-8.*_HVM-*-x86_64-*"] # tells AWS to only find AMIs whose name matches this Red Hat naming pattern.
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"] # # ensures the AMI uses HVM (Hardware Virtual Machine) virtualization
  }
}

############################################
# creating Jenkins Host Security Group
############################################
resource "aws_security_group" "jenkins-sg" {
  name        = "${local.name}-jenkins-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.proj_vpc.id
  ingress {
    description     = "Allow Jenkins"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_elb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}
############################################
# creating IAM role for EC2 to use SSM
############################################
resource "aws_iam_role" "jenkins_ssm_role" {
  name = "${local.name}-jenkins_ssm_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Name = "${local.name}-jenkins_ssm_role"
  }
}
############################################
# attaching SSM policy to the role
############################################
resource "aws_iam_role_policy_attachment" "jenkins_ssm_policy" {
  role       = aws_iam_role.jenkins_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# creating instance profile
resource "aws_iam_instance_profile" "jenkins_ssm_profile" {
  name = "${local.name}-jenkins_ssm_profile"
  role = aws_iam_role.jenkins_ssm_role.name
}
############################################
# creating Jenkins server instance
############################################
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.proj_key.id
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  subnet_id                   = aws_subnet.proj_pubsub_1.id
  iam_instance_profile        = aws_iam_instance_profile.jenkins_ssm_profile.id
  associate_public_ip_address = true
  user_data = templatefile("./jenkins.sh", {
    new_relic_key        = local.new_relic_cred.new_relic_key,
    new_relic_account_id = local.new_relic_cred.new_relic_account_id,
  })
  root_block_device {
    volume_size = 100
    volume_type = "gp2"
  }
  tags = {
    Name = "${local.name}-jenkins_server"
  }
}

############################################
# creating Bastion Host Security Group
############################################
resource "aws_security_group" "bastion-sg" {
  name        = "${local.name}-bastion-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.proj_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-bastion-sg"
  }
}
############################################
# creating IAM role for bastion host to use SSM
############################################
resource "aws_iam_role" "bastion_ssm_role" {
  name = "${local.name}-bastion_ssm_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Name = "${local.name}-bastion_ssm_role"
  }
}
############################################
# attaching SSM policy to the bastion host role
############################################
resource "aws_iam_role_policy_attachment" "bastion_ssm_policy" {
  role       = aws_iam_role.bastion_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# creating instance profile
resource "aws_iam_instance_profile" "bastion_ssm_profile" {
  name = "${local.name}-bastion_ssm_profile"
  role = aws_iam_role.bastion_ssm_role.name
}
############################################
# creating Bastion Host
############################################
resource "aws_instance" "bastion-server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.proj_pubsub_1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion-sg.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion_ssm_profile.id
  key_name                    = aws_key_pair.proj_key.id
  user_data = templatefile("./bastion.sh", {
    private_key          = tls_private_key.proj_key.private_key_pem
    new_relic_key        = local.new_relic_cred.new_relic_key,
    new_relic_account_id = local.new_relic_cred.new_relic_account_id,
  })
  tags = {
    Name = "${local.name}-bastion-server"
  }
}

############################################
# SECURITY GROUP FOR ANSIBLE CONTROL NODE
############################################
resource "aws_security_group" "ansible_sg" {
  name        = "${local.name}-ansible-sg"
  description = "Security group for Ansible control node allowing SSH access"
  vpc_id      = aws_vpc.proj_vpc.id
  # SSH access from anywhere
  ingress {
    description     = "Allow SSH from bastion host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id, aws_security_group.jenkins-sg.id] # Allow SSH from bastion host
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-ansible-sg"
  }
}
############################################
# creating IAM role for ansible to access aws s3
############################################
resource "aws_iam_role" "ansible_ssm_role" {
  name = "${local.name}-ansible_ssm_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Name = "${local.name}-ansible_ssm_role"
  }
}
############################################
# attaching SSM policy to the ansible role
############################################
resource "aws_iam_role_policy_attachment" "ansible_ssm_policy" {
  role       = aws_iam_role.ansible_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
# creating instance profile for ansible
resource "aws_iam_instance_profile" "ansible_ssm_profile" {
  name = "${local.name}-ansible_ssm_profile"
  role = aws_iam_role.ansible_ssm_role.name
}
############################################
# ANSIBLE CONTROL NODE
############################################
resource "aws_instance" "ansible" {
  ami                         = data.aws_ami.ubuntu.id # Use the latest Ubuntu 22.04 Jammy AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.proj_pubsub_1.id
  key_name                    = aws_key_pair.proj_key.key_name
  vpc_security_group_ids      = [aws_security_group.ansible_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ansible_ssm_profile.id
  associate_public_ip_address = true
  user_data = templatefile("./ansible.sh", {
    private_key          = tls_private_key.proj_key.private_key_pem,
    scripts_bucket_name  = var.scripts_bucket_name,
    stage_env_ip         = aws_instance.stage-env.private_ip,
    prod_env_ip_1        = data.aws_instances.prod_asg_instances.private_ips[0],
    prod_env_ip_2        = data.aws_instances.prod_asg_instances.private_ips[1],
    new_relic_key        = local.new_relic_cred.new_relic_key,
    new_relic_account_id = local.new_relic_cred.new_relic_account_id
  })
  tags = {
    Name = "${local.name}-ansible"
  }
}
resource "aws_s3_object" "scripts_upload" {
  for_each = fileset("${path.module}/scripts", "*")
  bucket   = var.scripts_bucket_name
  key      = "scripts/${each.value}"
  source   = "${path.module}/scripts/${each.value}"
  etag     = filemd5("${path.module}/scripts/${each.value}")
}

############################################
# creating Nexus security group
############################################
resource "aws_security_group" "nexus-sg" {
  name        = "${local.name}-nexus-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.proj_vpc.id
  ingress {
    description     = "This ingress is used for exposing Nexus application"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.nexus_elb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-nexus-sg"
  }
}
############################################
# creating IAM role for nexus server to use SSM
############################################
resource "aws_iam_role" "nexus_ssm_role" {
  name = "${local.name}-nexus_ssm_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Name = "${local.name}-nexus_ssm_role"
  }
}
############################################
# attaching SSM policy to the nexus server role
############################################
resource "aws_iam_role_policy_attachment" "nexus-ssm-policy" {
  role       = aws_iam_role.nexus_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# creating instance profile
resource "aws_iam_instance_profile" "nexus_ssm_profile" {
  name = "${local.name}-nexus_ssm_profile"
  role = aws_iam_role.nexus_ssm_role.name
}
############################################
# creating Nexus server
############################################
resource "aws_instance" "nexus-server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.proj_pubsub_2.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nexus-sg.id]
  iam_instance_profile        = aws_iam_instance_profile.nexus_ssm_profile.id
  key_name                    = aws_key_pair.proj_key.id
  user_data = templatefile("./nexus.sh", {
    new_relic_key        = local.new_relic_cred.new_relic_key,
    new_relic_account_id = local.new_relic_cred.new_relic_account_id
  })
  tags = {
    Name = "${local.name}-nexus-server"
  }
}

############################################
#creating security group for sonarqube server
############################################
resource "aws_security_group" "sonarqube-sg" {
  name        = "${local.name}-sonarqube-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.proj_vpc.id
  ingress {
    description     = "SonarQube"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.sonarqube_elb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-sonarqube-sg"
  }
}
resource "aws_iam_role" "sonarqube_ssm_role" {
  name = "${local.name}-sonarqube_ssm_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Name = "${local.name}-sonarqube_ssm_role"
  }
}
############################################
# attaching SSM policy to the sonarqube server role
############################################
resource "aws_iam_role_policy_attachment" "sonarqube-ssm-policy" {
  role       = aws_iam_role.sonarqube_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# creating instance profile
resource "aws_iam_instance_profile" "sonarqube_ssm_profile" {
  name = "${local.name}-sonarqube_ssm_profile"
  role = aws_iam_role.sonarqube_ssm_role.name
}
############################################
# creating sonarqube server
############################################
resource "aws_instance" "sonarqube-server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.proj_pubsub_2.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sonarqube-sg.id]
  iam_instance_profile        = aws_iam_instance_profile.sonarqube_ssm_profile.id
  key_name                    = aws_key_pair.proj_key.id
  user_data = templatefile("./sonarqube.sh", {
    new_relic_key        = local.new_relic_cred.new_relic_key,
    new_relic_account_id = local.new_relic_cred.new_relic_account_id
  })
  tags = {
    Name = "${local.name}-sonarqube-server"
  }
}

############################################
# DB SUBNET GROUP
############################################
resource "aws_db_subnet_group" "proj_db_subnet" {
  name = "${local.name}-db-subnet-group"
  subnet_ids = [
    aws_subnet.proj_prisub_1.id,
    aws_subnet.proj_prisub_2.id
  ]
  tags = {
    Name = "${local.name}-db-subnet-group"
  }
}
############################################
# RDS SECURITY GROUP
############################################
resource "aws_security_group" "rds_sg" {
  description = "Security group for RDS allowing MySQL access from app servers"
  name        = "${local.name}-rds-sg"
  vpc_id      = aws_vpc.proj_vpc.id
  ingress {
    description     = "Allow MySQL from app servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.docker-sg.id] # Allow MySQL access from Docker host 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-rds-sg"
  }
}

############################################
# RDS INSTANCE (MULTI-AZ)
############################################
resource "aws_db_instance" "proj_rds" {
  identifier             = "proj-rds"
  engine                 = "mysql" # MySQL database engine
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # Adjust based on your needs
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = local.db_cred.dbname
  username               = local.db_cred.username
  password               = local.db_cred.password
  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.proj_db_subnet.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  tags = {
    Name = "${local.name}-rds"
  }
}

############################################
# creating Docker security group
############################################
resource "aws_security_group" "docker-sg" {
  name        = "${local.name}-docker-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.proj_vpc.id
  ingress {
    description     = "java application port"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.stage_elb_sg.id, aws_security_group.prod_lb_sg.id]
  }
  ingress {
    description     = "ssh access"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id, aws_security_group.ansible_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-docker-sg"
  }
}
############################################
# creating Docker Host
############################################
resource "aws_instance" "stage-env" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.proj_prisub_2.id
  vpc_security_group_ids = [aws_security_group.docker-sg.id]
  key_name               = aws_key_pair.proj_key.id
  user_data = templatefile("./docker.sh", {
    new_relic_key        = local.new_relic_cred.new_relic_key,
    new_relic_account_id = local.new_relic_cred.new_relic_account_id,
  })
  tags = {
    Name = "${local.name}-stage-env"
  }
}

# create secret in AWS Secrets Manager to store RDS credentials
resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${local.name}-rds-credentials3"
  description             = "RDS credentials for Jenkins pipeline"
  recovery_window_in_days = 0 # Disable automatic deletion recovery window
  tags = {
    Name = "${local.name}-rds-credentials3"
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials_version" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    dbname               = var.rds_dbname
    username             = var.rds_username
    password             = var.rds_password
    new_relic_key        = var.new_relic_key
    new_relic_account_id = var.new_relic_account_id
  })
}


############################################
# LAUNCH TEMPLATE
############################################
resource "aws_launch_template" "prod_lt" {
  name_prefix   = "${local.name}-prod-lt"
  image_id      = data.aws_ami.ubuntu.id
  # image_id      = aws_ami_from_instance.ami.id
  instance_type = "t2.medium"
  key_name      = aws_key_pair.proj_key.key_name
  network_interfaces {
    security_groups = [aws_security_group.docker-sg.id]
  }
  metadata_options {
    http_tokens = "required"
  }
  user_data = base64encode(templatefile("./docker.sh", {
    new_relic_key        = local.new_relic_cred.new_relic_key,
    new_relic_account_id = local.new_relic_cred.new_relic_account_id,
  }))
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name}-prod-instance"
      Environment = "prod"
    }
  }
}

############################################
# AUTO SCALING GROUP
############################################
resource "aws_autoscaling_group" "prod_asg" {
  name             = "${local.name}-prod-asg"
  min_size         = 2
  max_size         = 4
  desired_capacity = 2
  vpc_zone_identifier = [
    aws_subnet.proj_prisub_1.id,
    aws_subnet.proj_prisub_2.id
  ]
  target_group_arns = [
    aws_lb_target_group.prod_tg.arn
  ]
  launch_template {
    id      = aws_launch_template.prod_lt.id
    version = "$Latest"
  }
  health_check_type = "EC2"
  tag {
    key                 = "Name"
    value               = "${local.name}-prod-instance"
    propagate_at_launch = true
  }
}

data "aws_instances" "prod_asg_instances" {
  filter {
    name   = "tag:Name"
    values = ["${local.name}-prod-instance"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
  depends_on = [aws_autoscaling_group.prod_asg]
}

############################################
# AUTO SCALING POLICY
############################################
resource "aws_autoscaling_policy" "cpu_policy" {
  name                   = "${local.name}-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.prod_asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
############################################
# create a public certificates from the amazon certificate manager
############################################
resource "aws_acm_certificate" "acm_cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${var.domain_name}-certificate"
  }
}

############################################
# get details about a Route 53 hosted zone
############################################
data "aws_route53_zone" "route53_zone" {
  name         = var.domain_name
  private_zone = false
}
############################################
# create a record set in route 53 for domain validation
############################################
resource "aws_route53_record" "route53_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.route53_zone.zone_id
}
############################################
# validate the acm (SSL) certifiacte
############################################
resource "aws_acm_certificate_validation" "acm_certificate_validation" {
  certificate_arn         = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.route53_record : record.fqdn]
}
############################################
# Create Route 53 record with Alias pointing to the following load-balancers:
# Jenkins DNS Record
############################################
resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = "jenkins.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.jenkins_clb.dns_name
    zone_id                = aws_elb.jenkins_clb.zone_id
    evaluate_target_health = true
  }
}

############################################
# Nexus DNS Record
############################################
resource "aws_route53_record" "nexus" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = "nexus.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.nexus_clb.dns_name
    zone_id                = aws_elb.nexus_clb.zone_id
    evaluate_target_health = true
  }
}
############################################
# SonarQube DNS Record
############################################
resource "aws_route53_record" "sonarqube" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = "sonarqube.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.sonarqube_clb.dns_name
    zone_id                = aws_elb.sonarqube_clb.zone_id
    evaluate_target_health = true
  }
}
############################################
# Stage DNS Record
############################################
resource "aws_route53_record" "stage" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = "stage.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_elb.stage_clb.dns_name
    zone_id                = aws_elb.stage_clb.zone_id
    evaluate_target_health = true
  }
}
############################################
# Production DNS Record
############################################
resource "aws_route53_record" "prod" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = "prod.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.prod_alb.dns_name
    zone_id                = aws_lb.prod_alb.zone_id
    evaluate_target_health = true
  }
}

# create Target Group
resource "aws_lb_target_group" "prod_tg" {
  name        = "${local.name}-prod-tg"
  target_type = "instance"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.proj_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  tags = {
    Name = "${local.name}-prod_tg"
  }
}

# create security group for production load balancer
resource "aws_security_group" "prod_lb_sg" {
  name        = "${local.name}-prod-lb-sg"
  description = "Allow HTTP/HTTPS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.proj_vpc.id
  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-prod-lb-sg"
  }
}

# create a Production Application load balancer
resource "aws_lb" "prod_alb" {
  name               = "${local.name}-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prod_lb_sg.id]
  subnets = [
    aws_subnet.proj_pubsub_1.id,
    aws_subnet.proj_pubsub_2.id
  ]
  enable_deletion_protection = false
  tags = {
    Name = "${local.name}-prod-alb"
  }
}

# create a listener
resource "aws_lb_listener" "http_listener" { # http listener (Redirect)
  load_balancer_arn = aws_lb.prod_alb.arn    # HTTP listeners on port 80 do not use TLS certificates.
  port              = "80"                   # Certificates are only used with HTTPS listeners.
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    target_group_arn = aws_lb_target_group.prod_tg.arn
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https_listener" { # https listener (forward traffic)
  load_balancer_arn = aws_lb.prod_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.acm_cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_tg.arn
  }
}

# Jenkins ELB Security group
resource "aws_security_group" "jenkins_elb_sg" {
  name        = "${local.name}-jenkins-elb-sg"
  description = "Jenkins ELB security group"
  vpc_id      = aws_vpc.proj_vpc.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward traffic to Jenkins instances"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-jenkins-elb-sg"
  }
}


# Jenkins Classic Load Balancer
resource "aws_elb" "jenkins_clb" {
  name = "${local.name}-jenkins-clb"
  subnets = [
    aws_subnet.proj_pubsub_1.id,
    aws_subnet.proj_pubsub_2.id
  ]
  security_groups = [aws_security_group.jenkins_elb_sg.id]

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.acm_cert.arn
  }

  health_check {
    target              = "TCP:8080"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances                   = [aws_instance.jenkins_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 60
  connection_draining         = true
  connection_draining_timeout = 300

  tags = {
    Name = "${local.name}-jenkins-clb"
  }
}

# sonarqube elb security group
resource "aws_security_group" "sonarqube_elb_sg" {
  name   = "${local.name}-sonarqube-elb-sg"
  vpc_id = aws_vpc.proj_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-sonarqube-elb-sg"
  }
}

# sonarqube classic load balancer
resource "aws_elb" "sonarqube_clb" {
  name = "${local.name}-sonarqube-clb"
  subnets = [
    aws_subnet.proj_pubsub_1.id,
    aws_subnet.proj_pubsub_2.id
  ]
  security_groups = [aws_security_group.sonarqube_elb_sg.id]

  listener {
    instance_port      = 9000
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.acm_cert.arn
  }

  health_check {
    target              = "TCP:9000"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances                   = [aws_instance.sonarqube-server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 60
  connection_draining         = true
  connection_draining_timeout = 300

  tags = {
    Name = "${local.name}-sonarqube-clb"
  }
}

# Nexus ELB security group
resource "aws_security_group" "nexus_elb_sg" {
  name   = "${local.name}-nexus-elb-sg"
  vpc_id = aws_vpc.proj_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-nexus-elb-sg"
  }
}


# Nexus classic Load Balancer
resource "aws_elb" "nexus_clb" {
  name = "${local.name}-nexus-clb"
  subnets = [
    aws_subnet.proj_pubsub_1.id,
    aws_subnet.proj_pubsub_2.id
  ]
  security_groups = [aws_security_group.nexus_elb_sg.id]

  listener {
    instance_port      = 8081
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.acm_cert.arn
  }

  health_check {
    target              = "TCP:8081"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances                   = [aws_instance.nexus-server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 60
  connection_draining         = true
  connection_draining_timeout = 300

  tags = {
    Name = "${local.name}-nexus-clb"
  }
}

# Stage (Docker) ELB security group
resource "aws_security_group" "stage_elb_sg" {
  name   = "${local.name}-stage-elb-sg"
  vpc_id = aws_vpc.proj_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-stage-elb-sg"
  }
}


# Stage (Docker) Classic Load Balancer
resource "aws_elb" "stage_clb" {
  name = "${local.name}-stage-clb"
  subnets = [
    aws_subnet.proj_pubsub_1.id,
    aws_subnet.proj_pubsub_2.id
  ]
  security_groups = [aws_security_group.stage_elb_sg.id]

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.acm_cert.arn
  }

  health_check {
    target              = "TCP:8080"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances                   = [aws_instance.stage-env.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 60
  connection_draining         = true
  connection_draining_timeout = 300

  tags = {
    Name = "${local.name}-stage-clb"
  }
}
