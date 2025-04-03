#\!/bin/bash

# Generate an SSH key
ssh-keygen -t rsa -b 2048 -f grafana-key -N "" -C "grafana-key"
echo "SSH key pair generated. Use grafana-key for SSH access to the Grafana instance."
echo "The public key has been saved as grafana-key.pub and will be used by Terraform."
echo "The private key has been saved as grafana-key. Keep this secure."
