output "bastian_ip" {
  value = aws_instance.bastian.public_ip
}

output "bastian" {
  value = format("%s (%s)", aws_instance.bastian.public_dns, aws_instance.bastian.public_ip)
}

output "control_plane_ip" {
  value = aws_instance.control_plane.public_ip
}

output "control_plane" {
  value = format("%s (%s)", aws_instance.control_plane.public_dns, aws_instance.control_plane.public_ip)
}

