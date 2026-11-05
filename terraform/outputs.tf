output "juice_shop_url" {
  value = "http://${aws_instance.app.public_ip}"
}

output "instance_id" {
  value = aws_instance.app.id
}

output "data_bucket" {
  value = aws_s3_bucket.data.bucket
}