# ===========================================================================
# Module COMPUTE : point d'entree public (ALB), couche applicative elastique
# (Launch Template + ASG + scaling CPU) et bastion d'administration.
# ===========================================================================

# AMI Ubuntu 22.04 la plus recente de Canonical (pas d'ID code en dur).
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Cle par environnement : detruire staging ne touche pas l'acces a prod.
resource "aws_key_pair" "admin" {
  key_name   = "${var.name_prefix}-key"
  public_key = var.public_key
}

# ---- Target Group : health check sur un chemin statique, independant de la
# base (une panne RDS ne doit pas retirer toutes les instances).
resource "aws_lb_target_group" "app" {
  name                 = "${var.name_prefix}-tg"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ---- ALB public multi-AZ, rejet des en-tetes HTTP malformes.
resource "aws_lb" "app" {
  name                       = "${var.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_sg_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = false # environnements academiques detruits en fin de TP
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ---- Modele unique des instances applicatives (identiques quel que soit l'env).
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.admin.key_name
  user_data     = filebase64("${path.module}/user_data_bootstrap.sh")

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_sg_id]
    delete_on_termination       = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 : protection SSRF
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 8
      volume_type           = "gp2"
      encrypted             = true
      delete_on_termination = true
    }
  }
}

# ---- ASG multi-AZ : capacites fournies par l'environnement (staging < prod).
resource "aws_autoscaling_group" "app" {
  name                      = "${var.name_prefix}-asg"
  min_size                  = var.asg_min
  desired_capacity          = var.asg_desired
  max_size                  = var.asg_max
  vpc_zone_identifier       = var.app_subnet_ids
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Tags propages : l'inventaire dynamique Ansible cible Project + Role et
  # construit les groupes staging/prod a partir de Environment.
  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-app"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  tag {
    key                 = "Role"
    value               = "app"
    propagate_at_launch = true
  }
  # Dependance implicite : reference le jeton du module reseau pour attendre
  # la NAT et les routes privees avant de lancer la moindre instance.
  tag {
    key                 = "NetworkReady"
    value               = substr(sha1(var.network_ready), 0, 8)
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                      = "${var.name_prefix}-cpu-target"
  autoscaling_group_name    = aws_autoscaling_group.app.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 180

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target
  }
}

# ---- Bastion : unique entree SSH, rebond d'Ansible vers les instances privees.
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = aws_key_pair.admin.key_name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  root_block_device {
    encrypted = true
  }

  tags = { Name = "${var.name_prefix}-bastion", Role = "bastion", Environment = var.environment }
}
