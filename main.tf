provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "eks-vpc"
  }
}
resource "aws_subnet" "eks_subnet" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "eks-subnet"
  }
}

resource "aws_subnet" "eks_subnet2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "eks-subnet-2"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "private-route-table"
  }
}
resource "aws_subnet" "alb_subnet" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-west-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "alb-subnet"
  }
}
resource "aws_subnet" "alb_subnet1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-west-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "alb-subnet2"
  }
}
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_route_table_assoc" {
  subnet_id      = aws_subnet.alb_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "public_route_table_assoc2" {
  subnet_id      = aws_subnet.alb_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "private_route_table_assoc_1" {
  subnet_id      = aws_subnet.eks_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_table_assoc_2" {
  subnet_id      = aws_subnet.eks_subnet2.id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_security_group" "eks_sg" {
  name        = "eks-security-group"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.27"

  vpc_config {
    subnet_ids         = [aws_subnet.eks_subnet.id, aws_subnet.eks_subnet2.id]
    security_group_ids = [aws_security_group.eks_sg.id]
  }
}
resource "aws_eks_fargate_profile" "fargate" {
  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = "my-fargate"
  pod_execution_role_arn = aws_iam_role.example1.arn
  subnet_ids             = [aws_subnet.eks_subnet.id, aws_subnet.eks_subnet2.id]

  selector {
    namespace = "app"
  }
}
resource "aws_iam_role" "example1" {
  name = "eks-fargate-profile-fargate"

  assume_role_policy = <<EOF
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "eks-fargate-pods.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.example1.name
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "my-eks-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_ecr_repository" "my_repository" {
  name = "my-eks-repo"
}

resource "aws_lb" "alb" {
  name               = "my-eks-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.eks_sg.id]
  subnets            = [aws_subnet.alb_subnet.id, aws_subnet.alb_subnet1.id]

  tags = {
    Name = "my-eks-alb"
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "my-eks-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"

  vpc_id = aws_vpc.eks_vpc.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    unhealthy_threshold = 2
    timeout             = 5
  }

  tags = {
    Name = "my-eks-target-group"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}