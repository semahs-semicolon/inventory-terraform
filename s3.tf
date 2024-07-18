
resource "aws_s3_bucket" "images" {
  bucket = "images"

  tags = {
    Name = "images"
  }
}
resource "aws_s3_bucket_acl" "images" {
  bucket = aws_s3_bucket.images.id
  acl    = "private"
}

resource "aws_s3_bucket" "scaled_images" {
  bucket = "scaled_images"
  tags = {
    Name = "scaled_images"
  }
}

resource "aws_s3_bucket_acl" "scaled_images" {
  bucket = aws_s3_bucket.scaled_images.id
  acl    = "private"
}