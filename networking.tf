resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = "true" #gives you an internal domain name
    enable_dns_hostnames = "true" #gives you an internal host name
    enable_classiclink = "false"
    instance_tenancy = "default" 
    tags = {
        Name = "cfox-vpc"
    }
    
}

resource "aws_subnet" "public-sub-1" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = "us-west-1a"    

}

resource "aws_subnet" "public-sub-2" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = "us-west-1b"    

}

resource "aws_subnet" "private-sub" {
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.3.0/24"
    map_public_ip_on_launch = "false" 
    availability_zone = "us-west-1a"    

}

resource "aws_internet_gateway" "igw" {
    vpc_id = "${aws_vpc.vpc.id}"

}

resource "aws_route_table" "public-crt" {
    vpc_id = "${aws_vpc.vpc.id}"
    
    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0"         //CRT uses this IGW to reach internet
        gateway_id = "${aws_internet_gateway.igw.id}" 
    }
    

}

resource "aws_route_table" "private-crt" {
    vpc_id = "${aws_vpc.vpc.id}"
    
    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0"         //CRT uses this IGW to reach internet
        gateway_id = "${aws_internet_gateway.igw.id}" 
    }
    

}

resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = "${aws_subnet.public-sub-1.id}"
  depends_on    = [aws_internet_gateway.igw]

}

resource "aws_route_table" "private-rt" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.private-rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.nat.id}"
}

resource "aws_route_table_association" "private-crta" {
  subnet_id      = "${aws_subnet.private-sub.id}"
  route_table_id = "${aws_route_table.private-rt.id}"
}

resource "aws_route_table_association" "crta-public-subnet-1"{
    subnet_id = "${aws_subnet.public-sub-1.id}"
    route_table_id = "${aws_route_table.public-crt.id}"
}

resource "aws_route_table_association" "crta-public-subnet-2"{
    subnet_id = "${aws_subnet.public-sub-2.id}"
    route_table_id = "${aws_route_table.public-crt.id}"
}