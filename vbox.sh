#!/bin/bash

# created this script on my free time
# it's useful because i don't have to
# type everything all the time.

function stop_vm() {
  print_line
  vboxmanage controlvm "$VM_NAME" poweroff
  if [[ "$?" -ne "0" ]]; then
    echo "PID LOCK, attempting to kill"
    kill_vm
    vboxmanage controlvm "$VM_NAME" poweroff
  fi
  rm ${VM_PID_FILE}
  vboxmanage showvminfo "$VM_NAME" | grep State
  print_line
}

function start_vm() {
  print_line
  echo "starting $VM_NAME in headless..."
  vboxheadless --startvm "$VM_NAME" & echo $! > ${VM_PID_FILE}
  if [[ "$?" -ne "0" ]]; then
    echo "VM was already running, stopping... try again."
    kill_vm
  fi
  print_line
}

function kill_vm() {
  echo "emergency stoping VM ${VM_NAME}..."
  vboxmanage startvm "$VM_NAME" --type emergencystop
  if [[ -n "$(ps aux | grep $(cat ${VM_PID_FILE}) | grep -v grep)" ]]; then
    echo "Stil running, attempting to use kill..."
    kill -9 $(cat ${VM_PID_FILE})
  fi
  stop_vm
}

function reset_vm() {
  vboxmanage controlvm "$VM_NAME" reset
}

function print_line() {
  echo "==========================================================="
}

function delete_vm() {
  print_line
  echo "Unregistering $VM_NAME ..."
  vboxmanage unregistervm "$VM_NAME" --delete
  echo "removing downloaded files in /tmp..."
  rm /tmp/${VM_IMG_NAME}
  echo "current list of VMs ..."
  vboxmanage list vms
  rm $VM_USR_FILE
  print_line
}

function usage() {
  echo "usage: $0 {start|stop|create|delete}"
  echo "if VBOX_URL is set, then the VM will be created using the"
  echo "iso file and the name of the VM will be the filename without .iso"
  exit 1
}

function init_vars() {
  VM_IMG_NAME=$(echo "$VM_URL" | grep -oP '([^\/]*\.iso)')
  VM_NAME=$(echo "$VM_IMG_NAME" | grep -oP '(.*[^.iso])')
  VM_VDI_PATH=${VM_DATA_PATH}/${VM_NAME}
  VM_VDI_FILE_PATH=${VM_DATA_PATH}/${VM_NAME}/${VM_NAME}.vdi
  VM_PID_FILE=${VM_DATA_PATH}/${VM_NAME}.pid
}

function eject_disc() {
  print_line
  echo "ejecting drive from $VM_NAME ..."
  VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 1 --device 0 --medium none --type dvddrive
  if [[ "$?" -ne "0" ]]; then
    echo "Something went wrong, drive is already removed or $VM_NAME does not exist"
  fi
  print_line
}

function create_vm() {
  echo "creating vm, ..."
  # Download image from nexus
  if [[ ! -f "/tmp/$VM_IMG_NAME" ]]; then
    cd /tmp
    wget $VM_URL
  fi
  # setting up file paths
  if [[ ! -d "$VM_DATA_PATH" ]]; then
    echo "the directory $VM_DATA_PATH does not exist"
    exit 1
  fi
  if [[ ! -d "$VM_VDI_PATH" ]]; then
    mkdir $VM_VDI_PATH
  fi
  # create VM
  vboxmanage createvm --name "$VM_NAME" --ostype "$VM_OSTYPE" --register
  vboxmanage modifyvm "$VM_NAME" --memory $VM_MEM --vram $VM_VRAM --acpi off --boot1 dvd --nic1 bridged --bridgeadapter1 $HOST_ADAPTER --chipset $VM_CHIPSET --ioapic on
  vboxmanage createhd --filename $VM_VDI_FILE_PATH --size $VM_HDD
  vboxmanage storagectl "$VM_NAME" --name "IDE Controller" --add ide
  vboxmanage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium $VM_VDI_FILE_PATH
  vboxmanage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium /tmp/${VM_IMG_NAME}
  vboxmanage modifyvm "$VM_NAME" --vrde on --cpu-profile "$VM_CPU_PROFILE"
}

# Globals
VM_URL="http://distro.ibiblio.org/puppylinux/puppy-xenial/32/xenialpup-7.5-uefi.iso"
VM_DATA_PATH=/var/lib/virtualbox
init_vars
VM_USR=$(whoami)
VM_MEM=1024
VM_HDD=10000
VM_VRAM=16
VM_OSTYPE="RedHat"
HOST_ADAPTER="ens160"
VM_USR_FILE=${VM_DATA_PATH}/${VM_USR}.url
VM_CPU_PROFILE="host"
VM_CHIPSET="ICH9"

# Main
if [[ ! -n "$1" ]]; then
  echo "Missing Arguments"
  usage
  exit 1
fi
if [[ ! -n "$(vboxmanage --version)" ]]; then
  echo "VirtualBox is not installed or wrong version"
  exit 1
fi
if [[ ! -n "$(vboxmanage list extpacks | grep Version)" ]]; then
  echo "VirtualBox extension pack is not installed or wrong version"
  exit 1
fi
if [[ -f $VM_USR_FILE ]]; then
  VBOX_URL=$(cat $VM_USR_FILE)
fi
if [[ -n "$VBOX_URL" ]]; then
  VM_URL=$VBOX_URL
  init_vars
  echo "$VBOX_URL" > $VM_USR_FILE
fi

if [[ "$1" = "create" ]]; then
  create_vm
  start_vm
elif [[ "$1" = "start" ]]; then
  start_vm
elif [[ "$1" = "stop" ]]; then
  stop_vm
elif [[ "$1" = "delete" ]]; then
  delete_vm
elif [[ "$1" = "reset" ]]; then
  reset_vm
elif [[ "$1" = "eject" ]]; then
  eject_disc
fi
