# Scripts

This directory contains utility scripts for the AWS Connect Analytics Pipeline project.

## Files

- **generate_ssh_key.sh** - Creates SSH keys for the Grafana EC2 instance
- **generate_ctr_data.py** - Generates test Contact Trace Records (CTR) for the pipeline
- **cleanup.sh** - Helps with manual resource cleanup if Terraform destroy fails

## Usage

Run the scripts from the project root directory, for example:

```bash
./scripts/generate_ssh_key.sh
./scripts/generate_ctr_data.py
./scripts/cleanup.sh
```

See the main README.md file or the documentation in the `docs/` directory for more details on using these scripts.