#!/bin/bash
# ami-8e1fece7 is a 64bit EBS based Amazon image
# user-data.sh is this file
#
# ec2-run-instances --user-data-file chefserver-ec2-user-data.sh --key allclearid -t m1.large ami-1aad5273 | grep INSTANCE | cut -f 2 | xargs -I AMI ec2-create-tags AMI --tag Name=chefserver
1
# ami-1aad5273  - ubuntu 11.04 64bit server ebs
# ami-2cc83145 - alestic ubunt 10.04 LTS 32bit server ebs
# ami-2ec83147 - alestic ubunt 10.04 LTS 64bit server ebs
# ami-8e1fece7  - amazon 64 bit ebs
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -e -x

# START SETUP BASE SYSTEM
apt-get -y install ncurses-term # because I use emacs ansi-term and want /usr/share/terminfo/e/eterm-color
apt-get -y install screen # because it's awesome, but needs a decent default config...

cat <<"EOS">/etc/skel/.screenrc
source /etc/screenrc
defscrollback 5000
termcapinfo xterm 'hs:ts=\E]2;:fs=\007:ds=\E]2;screen\007'
defhstatus "screen ^A (^Aa) | $USER@^AH"
hardstatus off
caption always "%{Yk} %H%{k}|%{W}%-w%{+u}%n %t%{-u}%+w"
caption string "%{yk}%H %{Kk}%{g}%-w%{kR}%n %t%{Kk}%{g}%+w"
startup_message off
vbell off
EOS

cat <<"EOS">/root/.screenrc
source /etc/screenrc
defscrollback 5000
termcapinfo xterm 'hs:ts=\E]2;:fs=\007:ds=\E]2;screen\007'
defhstatus "screen ^A (^Aa) | $USER@^AH"
hardstatus off
caption always "%{Yk} %H%{k}|%{W}%-w%{+u}%n %t%{-u}%+w"
caption string "%{yk}%H %{Kk}%{g}%-w%{kR}%n %t%{Kk}%{g}%+w"
startup_message off
vbell off
EOS

echo export HISTSIZE=5000 | tee -a /root/.bash_profile
echo export HISTSIZE=5000 | tee -a /etc/skel/.bash_profile

# END SETUP BASE SYSTEM


# ubuntu/debian
apt-get -y install ruby ruby-dev libopenssl-ruby rdoc ri irb \
build-essential wget ssl-cert \
couchdb couchdb-bin libcouchdb-glib-dev \
libgecode27 libgecode-dev \
rabbitmq-server \
openjdk-6-jre 
# sun-java6-jre

# centos5
#sudo rpm -Uvh http://download.fedora.redhat.com/pub/epel/5/i386/epel-release-5-4.noarch.rpm
#sudo wget -O /etc/yum.repos.d/aegis.repo http://rpm.aegisco.com/aegisco/el5/aegisco.repo
#sudo yum install ruby-1.8.7.334-2.el5 ruby-devel-1.8.7.334-2.el5 ruby-ri-1.8.7.334-2.el5 ruby-rdoc-1.8.7.334-2.el5 git gcc gcc-c++ automake autoconf make

cd /tmp
wget http://production.cf.rubygems.org/rubygems/rubygems-1.7.2.tgz
tar zxf rubygems-1.7.2.tgz
cd rubygems-1.7.2
ruby setup.rb --no-format-executable
cd -

gem install chef

cat <<EOF>/root/chef-solo.rb
file_cache_path "/tmp/chef-solo"
cookbook_path "/tmp/chef-solo/cookbooks"
EOF

cat<<EOF>/root/chef.json
{
  "chef_server": {
    "server_url": "http://localhost:4000",
    "webui_enabled": true,
    "init_style": "init"
  },
  "run_list": [ "recipe[chef-server::rubygems-install]" ]
}
EOF

chef-solo -c /root/chef-solo.rb -j ~/chef.json -r http://s.codecafe.com/cccookbooks.tgz

publicip=`/usr/bin/curl -s http://169.254.169.254/latest/meta-data/public-ipv4` && ( echo $publicip | /bin/mail -s "instance alive $publicip" ec2-notice@hippiehacker.org )
