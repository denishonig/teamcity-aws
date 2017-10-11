data "aws_region" "current" {
  current = true
}

module "network" {
  source               = "../network"
  environment          = "${var.environment}"
  vpc_cidr             = "${var.vpc_cidr}"
  public_subnet_cidrs  = "${var.public_subnet_cidrs}"
  private_subnet_cidrs = "${var.private_subnet_cidrs}"
  availibility_zones   = "${var.availibility_zones}"
  depends_id           = ""
}

module "efs" {
  source = "../efs"

  name    = "my-efs-mount"
  subnets = "${join(",", module.network.private_subnet_ids)}"
  vpc_id  = "${module.network.vpc_id}"
}

module "rds" {
  source = "../rds"

  vpc_id = "${module.network.vpc_id}"
  subnet_ids = "${module.network.private_subnet_ids}"
}

module "ecs_instances" {
  source = "../ecs_instances"

  environment             = "${var.environment}"
  cluster                 = "${var.cluster}"
  instance_group          = "${var.instance_group}"
  private_subnet_ids      = "${module.network.private_subnet_ids}"
  aws_ami                 = "${var.ecs_aws_ami}"
  instance_type           = "${var.instance_type}"
  max_size                = "${var.max_size}"
  min_size                = "${var.min_size}"
  desired_capacity        = "${var.desired_capacity}"
  vpc_id                  = "${module.network.vpc_id}"
  iam_instance_profile_id = "${aws_iam_instance_profile.ecs.id}"
  key_name                = "${var.key_name}"
  load_balancers          = "${var.load_balancers}"
  depends_id              = "${module.network.depends_id}"
  custom_userdata         = <<EOF
sudo mkdir /mnt/efs
sudo yum install -y nfs-utils
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "${module.efs.file_system_id}".efs."${data.aws_region.current.name}".amazonaws.com:/ /mnt/efs
sudo cp /etc/fstab /etc/fstab.bak
echo '"${module.efs.file_system_id}".efs."${data.aws_region.current.name}".amazonaws.com:/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0' | sudo tee -a /etc/fstab
sudo mount -a
sudo stop ecs
sudo service docker restart
sudo start ecs
EOF
  cloudwatch_prefix       = "${var.cloudwatch_prefix}"
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.cluster}"
}
