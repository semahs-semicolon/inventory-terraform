

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

    user_data = <<-EOL
        #!/bin/bash -xe
        apt update
        apt install postgresql --yes
        EOL
    // will take care of it manually
  
    tags = {
        Name = "Database"
    }

    key_name = aws_key_pair.keypair.key_name
}