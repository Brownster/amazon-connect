# ===================================================================
# NETWORKING INFRASTRUCTURE
# ===================================================================
# This file defines the VPC, subnets, and related resources for our application

# Create a Virtual Private Cloud (VPC) to host our Grafana instance
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr  # Define IP address range for the VPC
  enable_dns_support   = true          # Enable DNS resolution in the VPC
  enable_dns_hostnames = true          # Enable DNS hostnames in the VPC
  
  tags = merge(
    var.tags,
    {
      Name = "connect-analytics-vpc"
    }
  )
}

# Create a public subnet to host our Grafana instance
# Public subnets have direct route to the internet gateway
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr    # Define IP range for the subnet
  availability_zone       = var.availability_zone     # Specify the availability zone
  map_public_ip_on_launch = true                      # Automatically assign public IPs to instances
  
  tags = merge(
    var.tags,
    {
      Name = "connect-analytics-public"
    }
  )
}

# Create a private subnet (not used in current config but available for future use)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr         # Define IP range for the subnet
  availability_zone = var.availability_zone           # Specify the availability zone
  
  tags = merge(
    var.tags,
    {
      Name = "connect-analytics-private"
    }
  )
}

# Create an internet gateway to allow communication between VPC and the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    var.tags,
    {
      Name = "connect-analytics-igw"
    }
  )
}

# Create a route table for the public subnet with route to internet via IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  # Define a route to the internet (0.0.0.0/0) via the internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = merge(
    var.tags,
    {
      Name = "connect-analytics-public-route"
    }
  )
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}