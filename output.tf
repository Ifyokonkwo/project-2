output "jenkins_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}
output "ansible_private_ip" {
  value = aws_instance.ansible.private_ip
}
output "nexus_public_ip" {
  value = aws_instance.nexus-server.public_ip
}
output "stage_private_ip" {
  value = aws_instance.stage-env.private_ip
}
output "prod_private_ip_1" {
  value = data.aws_instances.prod_asg_instances.private_ips[0]
}
output "prod_private_ip_2" {
  value = data.aws_instances.prod_asg_instances.private_ips[1]
}
output "sonarqube_public_ip" {
  value = aws_instance.sonarqube-server.public_ip
}
output "bastion_public_ip" {
  value = aws_instance.bastion-server.public_ip
}