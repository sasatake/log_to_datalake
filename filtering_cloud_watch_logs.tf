provider "aws" {
  region = "${var.region}"
}

resource "aws_s3_bucket" "firehose_bucket" {
  bucket = "${var.prefix}-s3-firehose-sample"
}

resource "aws_kinesis_firehose_delivery_stream" "firehose" {
  name        = "${var.prefix}-firehose-stream-sample"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = "${aws_iam_role.firehose_role.arn}"
    bucket_arn         = "${aws_s3_bucket.firehose_bucket.arn}"
    buffer_interval    = 60
    compression_format = "GZIP"
  }
}

data "aws_cloudwatch_log_group" "kinesis_firehose_log_group" {
  name = "/aws/kinesisfirehose/${var.prefix}-firehose-stream-sample"
}

data "aws_iam_policy_document" "firehose_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "logs_to_firehose_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "firehose_role_policy" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]

    effect = "Allow"

    resources = ["${aws_s3_bucket.firehose_bucket.arn}", "${aws_s3_bucket.firehose_bucket.arn}/*"]
  }

  statement {
    actions = [
      "logs:PutLogEvents",
    ]

    effect = "Allow"

    resources = ["${data.aws_cloudwatch_log_group.kinesis_firehose_log_group.arn}"]
  }
}

data "aws_iam_policy_document" "logs_to_firehose_role_policy" {
  statement {
    actions = [
      "firehose:*",
    ]

    effect = "Allow"

    resources = ["${aws_kinesis_firehose_delivery_stream.firehose.arn}"]
  }

  statement {
    actions = [
      "iam:PassRole",
    ]

    effect = "Allow"

    resources = ["${aws_iam_role.logs_to_firehose_role.arn}"]
  }
}

resource "aws_iam_role" "firehose_role" {
  name               = "${var.prefix}-firehose-role"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.firehose_assume_role_policy.json}"
}

resource "aws_iam_role" "logs_to_firehose_role" {
  name               = "${var.prefix}-logs-to-firehose-role"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.logs_to_firehose_assume_role_policy.json}"
}

resource "aws_iam_role_policy" "firehose_role_policy" {
  name   = "${var.prefix}-firehose-role-policy"
  role   = "${aws_iam_role.firehose_role.id}"
  policy = "${data.aws_iam_policy_document.firehose_role_policy.json}"
}

resource "aws_iam_role_policy" "logs_to_firehose_role_policy" {
  name   = "${var.prefix}-logs-to-firehose-role-policy"
  role   = "${aws_iam_role.logs_to_firehose_role.id}"
  policy = "${data.aws_iam_policy_document.logs_to_firehose_role_policy.json}"
}

resource "aws_cloudwatch_log_subscription_filter" "logfilter" {
  name            = "${var.prefix}-logfilter"
  role_arn        = "${aws_iam_role.logs_to_firehose_role.arn}"
  log_group_name  = "/aws/lambda/chalice-sample-dev"
  filter_pattern  = "{$.app-name = chalice-sample}"
  destination_arn = "${aws_kinesis_firehose_delivery_stream.firehose.arn}"
  distribution    = "Random"
}
