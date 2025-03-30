resource "aws_s3_bucket" "ea_trading_bucket" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_ownership_controls" "ea_trading_bucket_ownership" {
  bucket = aws_s3_bucket.ea_trading_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "ea_trading_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.ea_trading_bucket_ownership]
  
  bucket = aws_s3_bucket.ea_trading_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "ea_trading_bucket_versioning" {
  bucket = aws_s3_bucket.ea_trading_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "ea_robot" {
  bucket = aws_s3_bucket.ea_trading_bucket.id
  key    = "ea/ForexGoldInvestor_v1.98_MT5.ex5"
  source = "${path.module}/ea/ForexGoldInvestor_v1.98_MT5.ex5"
  etag   = filemd5("${path.module}/ea/ForexGoldInvestor_v1.98_MT5.ex5")
}

resource "aws_s3_object" "ea_settings" {
  bucket = aws_s3_bucket.ea_trading_bucket.id
  key    = "ea/ForexGoldInvestor_v1.98_MT5.set"
  source = "${path.module}/ea/ForexGoldInvestor_v1.98_MT5.set"
  etag   = filemd5("${path.module}/ea/ForexGoldInvestor_v1.98_MT5.set")
}
