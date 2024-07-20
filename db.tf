

resource "aws_ssm_parameter" "database_password" {
  type = "SecureString"
  name = "database_password"
  value = "e"
}

resource "aws_key_pair" "keypair" {
  key_name = "mykey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC/uHBgHAti8a8ecqaC3szieRsPIOKgVfjiC72MJGDCFFOaNuZI36NXYicrTvH4KS2ScUF0R5MktnTHAhC8WhDEN39Qba4TH0FwzkIpAHhFEksHqxfdAe8OocxqF5tcoJCkl2AAF/tGMOw8M7yeaDqvVflGbilJu71sOOfVX+HDYh2jY/3qaKNAUcntS2oD0vFytfWJm9p5Tf9R++kN4nJ2BJLcTOk2W09s4wkzNG0nBC4L51iXiwVALx4HAojxKQkP2YHKtCOdD2G7LglFsIz3IjIoytYpu98E5mtErXOXUf2Yma+MmjzcmlrAJ9ptC/DJLFV4RlFzMV9Pqd0ZGBOZwejawfH7wNFo4q+K9GYNrOVEc2gr62dKReN/fncrRiuu/X6A8WfYdiu2r1aj6Tm/7aCMWg9iL9imfmX40eNEPiRSuA35UGwDwjZvL9afhhbV5L+AnsJHgdIKaja5w7kyAfG2ll5d6+novQ5p7w7/dQThDWzgBcfExjWUr1WVAu8= cyoung06@naver.com"
}

resource "aws_instance" "database" {
    ami = "ami-09cb0f54fe24c54a6"
    instance_type = "t4g.nano"

    subnet_id = aws_subnet.public_subnets["2a"].id

    vpc_security_group_ids = [ aws_default_security_group.default_sg.id ]

    user_data = <<-EOL
        #!/bin/bash -xe
        
        # update mirror
        sed -i 's/[a-zA-Z0-9_\\\-]*.clouds.ports.ubuntu.com/ftp.kaist.ac.kr/g' /etc/apt/sources.list.d/ubuntu.sources
        sed -i 's/ports.ubuntu.com/ftp.kaist.ac.kr/g' /etc/apt/sources.list.d/ubuntu.sources
        
        # install postgresql
        apt update
        apt install postgresql --yes
        apt install postgresql-server-dev-16 --yes



        # install pgvector
        git clone --branch v0.7.2 https://github.com/pgvector/pgvector.git
        cd pgvector
        apt install build-essential
        make
        make install
        cd ..

        # install textsearch-ko

        ## install mecab-ko
        wget https://bitbucket.org/eunjeon/mecab-ko/downloads/mecab-0.996-ko-0.9.2.tar.gz
        tar zxfv mecab-0.996-ko-0.9.2.tar.gz 
        cd mecab-0.996-ko-0.9.2
        ./configure --build=aarch64-unknown-linux-gnu 
        # well.... we're on aarch64.
        make
        make check
        make install
        cd ..

        ## install mecab ko dic
        wget https://bitbucket.org/eunjeon/mecab-ko-dic/downloads/mecab-ko-dic-2.1.1-20180720.tar.gz
        tar zxfv mecab-ko-dic-2.1.1-20180720.tar.gz
        cd mecab-ko-dic-2.1.1-20180720
        ./configure
        ldconfig
        make
        make install
        cd ..

        ## install actual textsearch ko
        git clone https://github.com/i0seph/textsearch_ko.git
        cd textsearch_ko
        ./build.sh 
        cd ..

        # provision accounts
        cat > /tmp/provision.sql <<EOF
        create database inventory;
        create user inventory_system;
        grant all privileges on database inventory to inventory_system;
        EOF

        sudo -u postgres psql -a -f /tmp/provision.sql
        cd textsearch_ko
        sudo -u postgres psql -f ts_mecab_ko.sql inventory
        cd ..

        ## pg_hba entry for db


        # apply database dump manually yourself.

        EOL
    // will take care of it manually
  
    tags = {
        Name = "Database"
    }

    key_name = aws_key_pair.keypair.key_name
}