# Workstation Bootstrap Based on Ubuntu Server

Install the latest Ansible.
```
sudo apt-add-repository ppa:ansible/ansible
sudo apt update
sudo apt install ansible
```

The file copy task will only copy files if they do not exist, so probably:
```
rm ~/.profile
```

Run this playbook.
```
sudo ansible-pull -U https://github.com/manadart/ansible-ubuntu-wayland
```
