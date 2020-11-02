#!/bin/bash
##For Pro-online check
##Support OS:SUSE12.3、SUSE12.4、SUSE12.5、CentOS7.4、CentOS8.1、RHEL7.4
##Create data：20200729
##Version:v1.0

export LANG=en
if [ -d /adminapp/auto_result ];then
  sleep 0.1
else
  mkdir -p /adminapp/auto_result
fi
file=/adminapp/auto_result/onlinecheckoutfile.json

##get info OS version
if [ -f /etc/SuSE-release ];then
  OS=SUSE
elif [ -f /etc/centos-release ];then
  OS=CentOS
elif [ -f /etc/redhat-release ];then
  OS=RHEL
else
  echo 'Support OS:SUSE、CentOS、RHEL'
  echo 'Error:unsuport OS version'
  exit 1
fi

if [ "$OS" = "SUSE" ];then
  Version=$(cat /etc/SuSE-release|grep VERSION|awk '{print $3}')
  SP=$(cat /etc/SuSE-release|grep PATCHLEVEL|awk '{print $3}')
elif [ "$OS" = "CentOS" ]|| [ "$OS" = "RHEL" ];then
  Version=$(cat /etc/redhat-release|grep release|awk '{print $(NF-1)}'|awk -F. '{print $1}')
  SP=$(cat /etc/redhat-release|grep release|awk '{print $(NF-1)}'|awk -F. '{print $2}')
fi

OsVer=$OS$Version.$SP

if [ "$OsVer" = "SUSE12.3" ] || [ "$OsVer" = "SUSE12.4" ] || [ "$OsVer" = "SUSE12.5" ];then
  sleep 0.1
elif [ "$OsVer" = "CentOS7.4" ] || [ "$OsVer" = "RHEL7.4" ] || [ "$OsVer" = "CentOS8.1" ];then
  sleep 0.1
else
  echo "Support OS:SUSE12.3-12.5 and CentOS7.4、CentOS8.1、RHEL7.4"
  echo "Error: Unsupport OS Version(This OS is $OsVer)"
  exit 1
fi

Statusfu(){
echo '"status":""},' >>$file
}

CheckStatus(){
if [ "$1" = "$2" ];then
  echo '"status":"Pass"},' >>$file
else
  echo '"status":"NoPass"},' >>$file
fi
}

CheckComplex(){
if [ "$1" = "$2" ] || [ "$1" = "$3" ];then
  echo '"status":"Pass"},' >>$file
else
  echo '"status":"NoPass"},' >>$file
fi
}

OsInfo(){
echo '"Hostname":{"value":"'$(hostname)\", >>$file
Statusfu
echo '"OS":{"value":"'$OsVer\", >>$file
Statusfu
echo '"Kernel":{"value":"'$(uname -r)\", >>$file
Statusfu
echo '"Biosdecode":{"value":"'$(biosdecode|grep 'biosdecode'|awk '{print $NF}')\", >>$file
Statusfu
echo '"Runlevel":{"value":"'$(systemctl get-default)\",  >>$file
CheckStatus "$(systemctl get-default)" "multi-user.target"
echo '"PATH":{"value":"'$(echo $PATH)\", >>$file
Statusfu
echo '"PS1":{"value":"'$(echo $(echo "echo \$PS1 && exit 0" | bash -i 2>/dev/null)|sed 's#\\#\\\\#g')\", >>$file
Statusfu
echo '"Time":{"value":"'$(date)\", >>$file
Statusfu
echo '"Hwclock":{"value":"'$(hwclock -r)\", >>$file
Statusfu
echo '"TimeZone":{"value":"'$(timedatectl status|grep "Time zone"|awk '{print $3}')\", 2>/dev/null >>$file
CheckStatus "$(timedatectl status|grep "Time zone"|awk '{print $3}')" "Asia/Shanghai"
echo '"SoftLimit":{"value":"'$(egrep "^\*\s+soft\s+nofile\s+" /etc/security/limits.conf|awk '{print $NF}')\", >>$file
CheckStatus "$(egrep '^\*\s+soft\s+nofile\s+' /etc/security/limits.conf|awk '{print $NF}')" "102400"
echo '"HardLimit":{"value":"'$(egrep "^\*\s+hard\s+nofile\s+" /etc/security/limits.conf|awk '{print $NF}')\", >>$file
CheckStatus "$(egrep '^\*\s+hard\s+nofile\s+' /etc/security/limits.conf|awk '{print $NF}')" "102400"
if [ "$OS" = "SUSE" ];then
  echo '"SuSEfirewall2":{"value":"'$(systemctl status SuSEfirewall2.service |grep Active|awk '{print $2}')\", >>$file
  CheckStatus "$(systemctl status SuSEfirewall2.service |grep Active|awk '{print $2}')" "inactive"
elif [ "$OS" = "CentOS" ] || [ "$OS" = "RHEL" ];then
  echo '"Firewalld":{"value":"'$(systemctl status firewalld.service |grep Active|awk '{print $2}')\", >>$file
  CheckStatus "$(systemctl status firewalld.service |grep Active|awk '{print $2}')" "inactive"
  echo '"Selinux":{"value":"'$(getenforce)\", >>$file
  CheckStatus "$(getenforce)" "Disabled"
fi
awk '{print $1}' /etc/hosts |uniq -d &>/dev/null
if [ "$?" = "0" ];then
  echo '"HostsDuplicate":{"value":"None",' >>$file
  echo  '"status":"Pass"},' >>$file
else
  echo '"HostsDuplicate":{"value":"'$(awk '{print $1}' /etc/hosts |uniq -d)'",' >>$file
  echo  '"status":"NoPass"},' >>$file
fi
echo '"/proc/cmdline":{"value":"'$(cat /proc/cmdline|xargs)\", >>$file
Statusfu
sysrq=$(grep '^kernel.sysrq' /etc/sysctl.conf)
retries=$(grep 'net.ipv4.tcp_retries2' /etc/sysctl.conf)
echo '"Sysctl":{"value":["'$sysrq'",''"'$retries'"],' >>$file
if [ "$sysrq" = "kernel.sysrq = 1" ] && [ "$retries" = "net.ipv4.tcp_retries2 = 10" ];then
  echo '"status":"Pass"},' >>$file
else
  echo '"status":"NoPass"},' >>$file
fi
if [ "$OS" = "CentOS" ] || [ "$OS" = "RHEL" ];then
  echo '"rc.local":{"value":"'$(ls -l /etc/rc.d/rc.local)'",' >>$file
  ls -l /etc/rc.d/rc.local|egrep '^-rwx' &>/dev/null
  if [ "$?" = "0" ];then
    echo '"status":"Pass"},' >>$file
  else
    echo '"status":"NoPass"},' >>$file
  fi
fi
}

ProductName(){
##ProductName##
echo '"ProductName":{"value":"'$(dmidecode |grep 'Product Name'|head -1|awk -F':' '{print $2}')\", >>$file
Statusfu
echo '"SystemSerialNumber":{"value":"'$(dmidecode -s system-serial-number)\", >>$file
Statusfu
}

CPUnumber(){
##number of CPU
echo '"CPU":{"value":"'$(grep 'processor' /proc/cpuinfo|wc -l)\", >>$file
Statusfu
}

Memory(){
##Memory##
echo '"Memery":{"value":"'$(free -h|grep -i Mem|awk '{print $2}')\", >>$file
Statusfu
echo '"Swap":{"value":"'$(free -h|grep -i Swap|awk '{print $NF}')\", >>$file
Statusfu
}

IPinfo(){
#ip addr#
TailIpaddr=`ip addr |grep '^[0-9]'|awk '{print $2}'|awk -F: '{print $1}'|tail -1`
echo '"Network":{"value":{' >>$file
for key in `ip addr |grep '^[0-9]'|awk '{print $2}'|awk -F: '{print $1}'`
do
  ipstatus=$(ip addr show dev $key|grep "<"|awk -F '[<>]+' '{print $2}')
  ipinfo=$(ip addr show dev $key|grep -w 'inet'|awk '{print $2}')
  if [ "$key" = "$TailIpaddr" ];then
    echo \"$key'":["'$ipstatus\", \"$ipinfo\"] >>$file
  else
    echo \"$key'":["'$ipstatus\", \"$ipinfo\"], >>$file
  fi
done
echo '},' >>$file
Statusfu
}

RouteInfo(){
##ip route list
TailIp=`ip route|tail -1`
echo '"RouteInfo":{"value":{' >>$file
n=1
IFS=$'\n\n'
for key in `ip route`
do
  if [ "$key" = "$TailIp" ];then
    echo '"RouteId-'$n'":"'$key\" >>$file
  else
    echo '"RouteId-'$n'":"'$key\", >>$file
  fi
  let n++
done
echo '},' >>$file
Statusfu
}

BondingStatus(){
##bonding status##
ls /proc/net/bonding &> /dev/null
if [ "$?" = "0" ];then
  dir='/proc/net/bonding'
  Tailbond=`ls /proc/net/bonding|tail -1`
  echo '"BondingStatus":{"value":{' >>$file
  for key in `ls /proc/net/bonding`
  do
  Interface1=$(grep -A 7 'Slave Interface' $dir/$key|head -8|grep 'Slave Interface'|awk -F ':' '{print $2}')
  Status=$(grep -A 7 'Slave Interface' $dir/$key|head -8|grep 'Status'|awk -F ':' '{print $2}')
  Speed=$(grep -A 7 'Slave Interface' $dir/$key|head -8|grep 'Speed'|awk -F ':' '{print $2}')
  MAC=$(grep -A 7 'Slave Interface' $dir/$key|head -8|grep 'HW addr'|awk '{print $NF}')
  Interface2=$(grep -A 7 'Slave Interface' $dir/$key|tail -8|grep 'Slave Interface'|awk -F ':' '{print $2}')
  Status2=$(grep -A 7 'Slave Interface' $dir/$key|tail -8|grep 'Status'|awk -F ':' '{print $2}')
  Speed2=$(grep -A 7 'Slave Interface' $dir/$key|tail -8|grep 'Speed'|awk -F ':' '{print $2}')
  MAC2=$(grep -A 7 'Slave Interface' $dir/$key|tail -8|grep 'HW addr'|awk '{print $NF}')
    echo '"BondingMode":"'$(grep 'Bonding Mode' /proc/net/bonding/$key|awk -F ':' '{print $2}')\", >>$file
    echo '"Info-'$key'":[' >>$file
    if [ "$key" = "$Tailbond" ];then
      echo '"'${Interface1}${Status}${Speed}${MAC}'","'${Interface2}${Status2}${Speed2}${MAC2}'"]' >>$file
    else
      echo '"'${Interface1}${Status}${Speed}${MAC}'","'${Interface2}${Status2}${Speed2}${MAC2}'"],' >>$file
    fi
  done
  echo '},' >>$file
  Statusfu
else
  echo '"BondingStatus":{"value":"NoBonding",' >>$file
  Statusfu
fi
}

DiskInfo(){
##disk info##
TailLsblk=`lsblk|grep -w 'disk'|awk '{print $1}'|tail -1`
echo '"DiskInfo":{"value":{' >>$file
for key in `lsblk|grep -w 'disk'|awk '{print $1}'`
do
  if [ "$key" = "$TailLsblk" ];then
    echo '"Disk-'$key'":"'$(lsblk|grep \^$key|awk '{print $4}')\", >>$file
  else
    echo '"Disk-'$key'":"'$(lsblk|grep \^$key|awk '{print $4}')\", >>$file
  fi
done
echo '},' >>$file
Statusfu
}

Partition(){
#partition#
TailFdisk=`fdisk -l|grep '^/dev/[sd?]'|awk '{print $1}'|tail -1`
echo '"Partition":{"value":{' >>$file
for key in `fdisk -l|grep '^/dev/[sd?]'|awk '{print $1}'`
do
  if [ "$key" = "$TailFdisk" ];then
    echo '"Disk-'$key'":"'$(fdisk -l|grep -w $key|awk '{print $1,$2,$3,$4,$5,$6,$7,$8}')'"' >>$file
  else
    echo '"Disk-'$key'":"'$(fdisk -l|grep -w $key|awk '{print $1,$2,$3,$4,$5,$6,$7,$8}')'",' >>$file
  fi
done
echo \}, >>$file
Statusfu
}

PVS(){
#pvs#
TailPvs=`pvs |grep -v 'PV'|awk '{print $1}'|tail -1`
echo '"Pvs":{"value":{' >>$file
for key in $(pvs |grep -v 'PV'|awk '{print $1}')
do
  if [ "$key" = "$TailPvs" ];then
    echo '"PvName-'$key'":"'$(pvs|grep -w "$key"|awk '{print $1,$2,$3,$4,$5,$6}')'"' >>$file
  else
    echo '"PvName-'$key'":"'$(pvs|grep -w "$key"|awk '{print $1,$2,$3,$4,$5,$6}')'",' >>$file
  fi
done
echo '},' >>$file
Statusfu
}

VGS(){
##vgs###
TailVgs=`vgs|grep -v 'VG'|awk '{print $1}'|tail -1`
echo '"Vgs":{"value":{' >>$file
for key in $(vgs|grep -v 'VG'|awk '{print $1}')
do
  if [ "$key" = "$TailVgs" ];then
    echo '"VgName-'$key'":"'$(vgs|grep -w $key|awk '{print $1,$2,$3,$4,$5,$6,$7}')'"' >>$file
  else
    echo '"VgName-'$key'":"'$(vgs|grep -w $key|awk '{print $1,$2,$3,$4,$5,$6,$7}')'",' >>$file
  fi
done
echo \}, >>$file
Statusfu
}

LVS(){
##lvs###
TailLvs=`lvs|grep -v 'VG'|awk '{print $1,$2,$3,$4}'|tail -1`
echo '"Lvs":{"value":{' >>$file
IFS=$'\n\n'
i=1
for key in $(lvs|grep -v 'VG'|awk '{print $1,$2,$3,$4}')
do
  if [ "$key" = "$TailLvs" ];then
    echo '"LvName-'$i'":"'$key'"' >>$file
  else
    echo '"LvName-'$i'":"'$key'",' >>$file
  fi
  let i++
done
echo '},' >>$file
Statusfu
}

Filesystem(){
##fs info,mountedon,fsstat
TailFs=`ls -l $(df -hT|grep \^/dev/|awk '{print $1}')|awk '{print $NF}'|awk -F'/' '{print $NF}'|tail -1`
echo '"Filesystem":{"value":{' >>$file
for key in `ls -l $(df -hT|grep \^/dev/|awk '{print $1}')|awk -F '[/ ]+' '{print $NF}'`
do
  mountponit=$(tune2fs -l /dev/$key|grep 'Last mounted on'|awk '{print $NF}')
  fsstate=$(tune2fs -l /dev/$key|grep 'Filesystem state'|awk '{print $NF}')
  if [ "$key" = "$TailFs" ];then
    echo '"Device-/dev/'$key'":["'$mountponit'","'$fsstate'"]' >>$file
  else
    echo '"Device-/dev/'$key'":["'$mountponit'","'$fsstate'"],' >>$file
  fi
done
echo \}, >>$file
Statusfu
}

FsType(){
##fs type,mountdir
TailDf=`df -hT|grep \^/dev/|awk '{print $1}'|tail -1`
echo '"FsType":{"value":{' >>$file
for key in $(df -hT|grep \^/dev/|awk '{print $1}')
do
  str1=$(df -hT|grep -w $key|awk '{print $2}')
  str2=$(df -hT|grep -w $key|awk '{print $NF}')
  if [ "$key" = "$TailDf" ];then
    echo '"FsDevice-'$key'":["'$str1'","'$str2'"]' >>$file
  else
    echo '"FsDevice-'$key'":["'$str1'","'$str2'"],' >>$file
  fi
done
echo '},' >>$file
Statusfu
}

BootDirInfo(){
##/boot info list###
echo '"/bootDirList":{"value":{' >>$file
i=1
TailBoot=`ls /boot|tail -1`
for key in `ls /boot`
do
  if [ "$key" = "$TailBoot" ];then
    echo '"ListID-'$i'":"'$key'"' >>$file
  else
    echo '"ListID-'$i'":"'$key'",' >>$file
  let i++
  fi
done
echo \}, >>$file
Statusfu
}

KdumpCrash(){
##show /var/crash dir
if [ "$(ls /var/crash|wc -l)" = "0" ];then
  echo '"CrashFile":{"value":"None",' >>$file
  Statusfu
fi
if [ "$(ls /var/crash|wc -l)" != "0" ];then
  TailCrash=`ls /var/crash/|tail -1`
  n=1
  echo '"CrashFile":{"value":{' >>$file
  echo '"FileNumber":"'$(ls /var/crash|wc -l)\", >>$file
  for key in `ls /var/crash`
  do
    if [ "$key" = "$TailCrash" ];then
      echo '"ListDir-'$n'":"'$key'"' >>$file
    else
      echo '"ListDir-'$n'":"'$key'",' >>$file
    fi
    let n++
  done
  echo '},' >>$file
  Statusfu
fi
}

PasswdComplex(){
###passwd complex
if [ "$OS" = "SUSE" ];then
  echo '"PasswdComplex":{"value":"'$(cat /etc/pam.d/common-password|grep pam_cracklib.so)\", >>$file
  CheckComplex "$(grep 'pam_cracklib.so' /etc/pam.d/common-password|awk -F 'pam_cracklib.so' '{print $2}')" \
  " minlen=8 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1" "	minlen=8 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1 "
elif [ "$OS" = "CentOS" ] || [ "$OS" = "RHEL" ];then
  echo '"PasswdComplex":{"value":{' >>$file
  n=1
  IFS=$'\n\n'
  TailComplex=$(egrep -v '^#|^$' /etc/security/pwquality.conf|egrep 'minlen|dcredit|ucredit|lcredit|ocredit'|tail -1)
  for key in `egrep -v '^#|^$' /etc/security/pwquality.conf|egrep 'minlen|dcredit|ucredit|lcredit|ocredit'`
  do
    if [ "$key" = "$TailComplex" ];then
      echo '"Complexline-'$n'":"'$key'"' >>$file
    else
      echo '"Complexline-'$n'":"'$key'",' >>$file
    fi
    let n++
  done
  echo \}, >>$file
  Len=`egrep -v '^#|^$' /etc/security/pwquality.conf|grep 'minlen'|awk '{print $NF}'`
  Dc=`egrep -v '^#|^$' /etc/security/pwquality.conf|grep 'dcredit'|awk '{print $NF}'`
  Uc=`egrep -v '^#|^$' /etc/security/pwquality.conf|grep 'ucredit'|awk '{print $NF}'`
  Lc=`egrep -v '^#|^$' /etc/security/pwquality.conf|grep 'lcredit'|awk '{print $NF}'`
  Oc=`egrep -v '^#|^$' /etc/security/pwquality.conf|grep 'ocredit'|awk '{print $NF}'`
  if [ "$Len" = "8" ] || [ "$Len" = "15" ] && [ "$Dc" = "-1" ] && [ "$Uc" = "-1" ] && [ "$Lc" = "-1" ] && [ "$Oc" = "-1" ];then
    echo '"status":"Pass"},' >>$file
  else
    echo '"status":"NoPass"},' >>$file
  fi
fi
}

ServiceEnabled(){
##service is enable
i=1
TailService=`systemctl list-unit-files|grep enabled|awk '{print $1}'|tail -1`
echo '"ServiceEnabled":{"value":{' >>$file
for key in `systemctl list-unit-files|grep enabled|awk '{print $1}'`
do
  if [ "$key" = "$TailService" ];then
    echo '"Service-'$i'":"'$key'"' >>$file
  else
    echo '"Service-'$i'":"'$key'",' >>$file
  fi
  let i++
done
echo '},' >>$file
Statusfu
}

Vsftpd(){
##vsftpd state
rpm -q vsftpd &>/dev/null
if [ "$?" = "0" ];then
  vsstatus=$(systemctl status vsftpd.service |grep Active|awk '{print $2}')
  echo '"VsftpdService":{"value":{"ServiceStatus":"'$vsstatus\", >>$file
  echo '"Vsftpdrpm":"'$(rpm -q vsftpd)\", >>$file
  if [ "$OS" = "CentOS" ] || [ "$OS" = "RHEL" ];then
    echo '"Anonymous":"'$(grep 'anonymous_enable' /etc/vsftpd/vsftpd.conf)'"},' >>$file
  elif [ "$OS" = "SUSE" ];then
    echo '"Anonymous":"'$(grep 'anonymous_enable' /etc/vsftpd.conf)'"},' >>$file
  fi
else
  echo '"VsftpdService":{"value":"NoInstall",' >>$file
fi
if [ "$(systemctl status vsftpd.service |grep Active|awk '{print $2}')" = "inactive" ];then
  echo '"status":"Pass"},' >>$file
else
  echo '"status":"NoPass"},' >>$file
fi
}

Crontab(){
##show crond
if [ "$OS" = "SUSE" ];then
  echo '"CrondService":{"value":{"ServiceStatus":"'$(systemctl status cron.service|grep 'Active'|awk '{print $2}')\", >>$file
  ls /etc/cron.d/hwctime &>/dev/null
  if [ "$?" = "0" ];then
    str=$(echo $(echo $(egrep -v '^#|^$' /etc/cron.d/hwctime)|sed 's#\\#\\\\#g')|sed 's#\"#\\\"#g')
    echo '"HwctimeFile":"'$str'"},' >>$file
  else
    echo '"HwctimeFile":"NoFile"},' >>$file
  fi
  if [ "$(systemctl status cron.service|grep 'Active'|awk '{print $2}')" = "active" ];then
    echo '"status":"Pass"},' >>$file
  else
    echo '"status":"NoPass"},' >>$file
  fi
elif [ "$OS" = "CentOS" ] || [ "$OS" = "RHEL" ];then
  echo '"CrondService":{"value":{"ServiceStatus":"'$(systemctl status crond.service|grep 'Active'|awk '{print $2}')\", >>$file
  ls /etc/cron.d/hwctime &>/dev/null
  if [ "$?" = "0" ];then
    str=$(echo $(echo $(egrep -v '^#|^$' /etc/cron.d/hwctime)|sed 's#\\#\\\\#g')|sed 's#\"#\\\"#g')
    echo '"HwctimeFile":"'$str'"},' >>$file
  else
    echo '"HwctimeFile":"NoFile"},' >>$file
  fi
  if [ "$(systemctl status crond.service|grep 'Active'|awk '{print $2}')" = "active" ];then
    echo '"status":"Pass"},' >>$file
  else
    echo '"status":"NoPass"},' >>$file
  fi
fi
}

DnsInfo(){
##dns
rpm -q nscd &>/dev/null
if [ "$?" = "0" ];then
  nsstatus=$(systemctl status nscd.service|grep 'Active'|awk '{print $2}')
  echo '"DnsService":{"value":{"NscdServiceStatus":"'$nsstatus\", >>$file
  echo '"CacheHosts":"'$(egrep 'enable-cache\s+hosts\s+' /etc/nscd.conf|awk '{print $NF}')\", >>$file
  echo '"TimeHosts":"'$(egrep 'positive-time-to-live\s+hosts\s+' /etc/nscd.conf|awk '{print $NF}')\", >>$file
else
  echo '"DnsService":{"value":{"NscdService":"NoInstall",' >>$file
fi
echo '"SshdDns":"'$(grep UseDNS /etc/ssh/sshd_config)\", >>$file
n=1
grep -w 'nameserver' /etc/resolv.conf &>/dev/null
if [ "$?" = "0" ];then
  TailRe=`grep -w nameserver /etc/resolv.conf|awk '{print $2}'|tail -1`
  for key in `grep -w nameserver /etc/resolv.conf|awk '{print $2}'`
  do
    if [ "$key" = "$TailRe" ];then
      echo \"DnsServer$n'":"'$key\"\}, >>$file
    else
      echo \"DnsServer$n'":"'$key\", >>$file
    fi
  let n++
  done
else
  echo '"DnsServer":"None"},' >>$file
fi
Statusfu
}

NtpStatus(){
##ntpd service 
if [ "$(systemctl status ntpd.service|grep -w 'Active'|awk '{print $2}')" = "active" ];then
  echo '"NtpServer":{"value":{' >>$file
  echo '"ServiceStatus":"active",' >>$file
  echo '"Master":"'$(ntpq -p -n|grep -e '^*'|awk -F "[* ]+" '{print $2}')\", >>$file
  echo '"Slave":"'$(ntpq -p -n|grep -e '^+'|awk -F "[+ ]+" '{print $2}')\", >>$file
  if [ "$OS" = "CentOS" ] || [ "$OS" = "RHEL" ];then
    echo '"OPTIONS":"'$(grep 'OPTIONS' /etc/sysconfig/ntpd|awk -F '"' '{print $2}')\" >>$file
  elif [ "$OS" = "SUSE" ];then
    echo '"OPTIONS":"'$(grep 'OPTIONS' /etc/sysconfig/ntp|awk -F '"' '{print $2}')\" >>$file
  fi
  echo '},' >>$file
  echo '"status":"Pass"},' >>$file
else
  echo '"NtpServer":{"value":"'$(systemctl status ntpd.service|grep -w 'Active'|awk '{print $2}')\", >>$file
  CheckStatus "$(systemctl status ntpd.service|grep -w 'Active'|awk '{print $2}')" "active"
fi
}

Rsyslog(){
##rsyslog info
echo '"RsyslogInfo":{"value":{' >>$file
echo '"ServiceStatus":"'$(systemctl status rsyslog.service|grep -w 'Active'|awk '{print $2}')\", >>$file
rpm -q logrotate &>/dev/null
if [ "$?" = "0" ];then
  echo '"Rpm":"'$(rpm -qa|grep logrotate)\", >>$file
else
  echo '"Rpm":"None",' >>$file
fi
grep '^kern' /etc/rsyslog.conf &>/dev/null
if [ "$?" = "0" ];then
#  n=1
  IFS=$'\n\n'
  Tailrsyslog=`grep '^kern' /etc/rsyslog.conf|uniq|tail -1`
  echo '"RsyslogHost":[' >>$file
  for key in `grep '^kern' /etc/rsyslog.conf|uniq`
  do
    if [ "$key" = "$Tailrsyslog" ];then
      echo '"'$key\"\] >>$file
    else
      echo '"'$key\", >>$file
    fi
#  let n++
  done
  echo '},' >>$file
else
  echo '"RsyslogHost":"None"},' >>$file
fi
if [ "$(systemctl status rsyslog.service|grep -w 'Active'|awk '{print $2}')" = "active" ];then
  echo '"status":"Pass"},' >>$file
else
  echo '"status":"NoPass"},' >>$file
fi
}

LocalFile(){
##after.local or rc.local file show
if [ "$OS" = "SUSE" ];then
  n=1
  IFS=$'\n\n'
  TailLocal=`egrep -v "^#|^$" /etc/init.d/after.local|uniq|tail -1`
  echo '"LocalFile":{"value":{' >>$file
  for key in `egrep -v '^#|^$' /etc/init.d/after.local|uniq`
  do
    if [ "$key" = "$TailLocal" ];then
      keynew=`echo $key|sed 's#\"#\\\"#g'`
      echo '"RowID-'$n'":"'$keynew'"' >>$file
    else
      keynew=`echo $key|sed 's#\"#\\\"#g'`
      echo '"RowID-'$n'":"'$keynew'",' >>$file
    fi
    let n++
  done
  echo '},' >>$file
  Statusfu
elif [ "$OS" = "CentOS" ] || [ "$OS" = "RHEL" ];then
  n=1
  IFS=$'\n\n'
  TailLocal=`egrep -v '^#|^$' /etc/rc.d/rc.local|uniq|tail -1`
  echo '"LocalFile":{"value":{' >>$file
  for key in `egrep -v '^#|^$' /etc/rc.d/rc.local|uniq`
  do
    if [ "$key" = "$TailLocal" ];then
      keynew=`echo $key|sed 's#\"#\\\"#g'`
      echo '"RowID-'$n'":"'$keynew'"' >>$file
    else
      keynew=`echo $key|sed 's#\"#\\\"#g'`
      echo '"RowID-'$n'":"'$keynew'",' >>$file
    fi
    let n++
  done
  echo '},' >>$file
  Statusfu
fi
}

UserInfo(){
##show can login user
array=(root oracle grid informix mysql redis mqm tuxedo tomcat websphere
at bin daemon ftp games lp man news nobody uucp
)
TailPasswd=`egrep '/bin/bash|/bin/ksh|/bin/sh' /etc/passwd|awk -F: '{print $1}'|tail -1`
echo '"UserInfo":{"value":{' >>$file
for key in `egrep '/bin/bash|/bin/ksh|/bin/sh' /etc/passwd|awk -F':' '{print $1}'`
do
  info=$(grep -w ^$key /etc/passwd|awk -F':' '{print $1,$3,$4,$6}')
  mask=$(su - $key -c 'umask')
  if [ "$key" =  "$TailPasswd" ];then
    echo '"UserName-'$key'":["'$info'","'$mask'"]' >>$file
  else
    echo '"UserName-'$key'":["'$info'","'$mask'"],' >>$file
  fi
done
echo '},' >>$file
Statusfu
}

GroupInfo(){
##show group info
TailGroup=`egrep -v \"$str\" /etc/group|awk -F ':' '{print $1}'|tail -1`
echo '"GroupInfo":{"value":{' >>$file
for key in `egrep -v \"$str\" /etc/group|awk -F ':' '{print $1}'`
do
  if [ "$key" = "$TailGroup" ];then
    echo '"GroupName-'$key'":"'$(grep -w ^$key /etc/group|awk -F: '{print $0}')'"' >>$file
  else
    echo '"GroupName-'$key'":"'$(grep -w ^$key /etc/group|awk -F: '{print $0}')'",' >>$file
  fi
done
echo '},' >>$file
echo '"status":""}' >>$file
}

main(){
echo '{' >$file

OsInfo
ProductName
CPUnumber
Memory
IPinfo
RouteInfo
BondingStatus
DiskInfo
Partition
PVS
VGS
LVS
Filesystem
FsType
BootDirInfo
KdumpCrash
PasswdComplex
ServiceEnabled
Vsftpd
Crontab
DnsInfo
NtpStatus
Rsyslog
LocalFile
UserInfo
GroupInfo

echo '}' >>$file
#####complete-info####
echo "$OsVer-$(hostname): Pro-online check is completed!"
}

main $*
