// this file is for image embedding generator, for iamge search

module "image_embedding" {
  source  = "philschmid/sagemaker-huggingface/aws"
  version = "0.9.0"
  name_prefix          = "image_embedding"
  pytorch_version      = "1.13.1"
  transformers_version = "4.26.0"
  hf_model_id          = "clip-ViT-B-32"
  hf_task              = "feature-extraction"
  serverless_config = {
    max_concurrency   = 1
    memory_size_in_mb = 1024
  }
  instance_type        = "ml.m5.xlarge"
}
