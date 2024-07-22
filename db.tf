

resource "aws_ssm_parameter" "database_password" {
  type = "SecureString"
  name = "database_password"
  value = "e"
  overwrite = false


  lifecycle {
    ignore_changes  = ["value", "overwrite"]
  }
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
        apt install build-essential --yes
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

        # I know, I also don't like snap, but this is only way to install aws-cli so please leave it this way. Or you could fix apt-repo but I'm lazy
        sudo snap install aws-cli --classic
        PASSWORD=$(aws ssm get-parameter --name database_password --with-decryption --query "Parameter.Value" --output text)


        # provision accounts
        cat > /tmp/provision.sql <<EOF
        create database inventory;
        create user inventory_system WITH ENCRYPTED PASSWORD '$${PASSWORD}';
        grant all privileges on database inventory to inventory_system;
        EOF

        sudo -u postgres psql -a -f /tmp/provision.sql
        rm -rf /tmp/provision.sql

        cd textsearch_ko
        sudo -u postgres psql -f ts_mecab_ko.sql inventory
        cd ..

        ## pg_hba entry for db
        echo "host    all             all             0.0.0.0/0               scram-sha-256" >> /etc/postgresql/16/main/pg_hba.conf 
        echo "listen_addresses = '*'" >> /etc/postgresql/16/main/postgresql.conf

        # apply database dump manually yourself.

        # database backup to s3 cron job!

        cat > /root/backup.sh <<EOF
        #!/bin/bash
        BUCKET_NAME=${aws_s3_bucket.dbbackup.id}

        TIMESTAMP=$(date +%F_%T | tr ':' '-')
        TEMP_FILE=$(mktemp tmp.XXXXXXXXXX)
        S3_FILE="s3://$BUCKET_NAME/backup-\$TIMESTAMP"

        sudo -u postgres pg_dump -Fc --no-acl inventory > \$TEMP_FILE
        gz $TEMP_FILE
        aws s3 cp \$TEMP_FILE.gz \$S3_FILE
        rm "\$TEMP_FILE.gz"

        (crontab -l 2>/dev/null; echo "0 0 * * * /root/backup.sh") | crontab -
        EOF


        chmod +x /root/backup.sh
        # we do daily backup. Each backup is like 2.3M

        systemctl restart postgresql
        EOL
    // will take care of it manually
  
    tags = {
        Name = "Database"
    }

    key_name = aws_key_pair.keypair.key_name

    iam_instance_profile = aws_iam_instance_profile.dbprofile.id
}

data "aws_iam_policy_document" "db_backup" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "allow_backup" {
  statement {
    effect = "Allow"

    resources = [ aws_s3_bucket.dbbackup.arn, "${aws_s3_bucket.dbbackup.arn}/*"]

    actions = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
  }
  statement {
    effect = "Allow"

    resources = [aws_ssm_parameter.database_password.arn]

    actions = ["ssm:GetParameter", "kms:Decrypt"]
  }
}

resource "aws_iam_role" "db_backup" {
  name               = "db_backup"
  assume_role_policy = data.aws_iam_policy_document.db_backup.json

  
  inline_policy {
    name = "allow_backup"
    policy = data.aws_iam_policy_document.allow_backup.json
  }
}

resource "aws_iam_instance_profile" "dbprofile" {
  name = "db_profile"
  role = aws_iam_role.db_backup.name
}

resource "aws_s3_bucket" "dbbackup" {
  bucket = "semicolon-dbdump"
  tags = {
    Name = "semicolon-dbdump"
  }
}

