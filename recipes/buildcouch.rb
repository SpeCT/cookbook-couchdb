#
# Author:: Yury Proshchenko <spect.man@gmail.com>
# Cookbook Name:: couchdb
# Recipe:: build-couch
#
# Copyright 2013, Yury Proshchenko
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

couchdb_tar_gz = File.join(Chef::Config[:file_cache_path], "build-couch.zip")
working_dir    = File.join(Chef::Config[:file_cache_path], "build-couchdb")
build_dir      = "/usr/local"
#build_dir      = "/opt/couchdb-#{node['couch_db']['src_version']}")
#install_dir    = "/opt/couchdb-#{node['couch_db']['src_version']}")

compile_flags = String.new
dev_pkgs = Array.new


if platform_family?("debian")

  dev_pkgs << "build-essential"
  dev_pkgs << "help2man"
  dev_pkgs << "make"
  dev_pkgs << "gcc"
  dev_pkgs << "zlib1g-dev"
  dev_pkgs << "libssl-dev"
  dev_pkgs << "rake"
  dev_pkgs << "texinfo"
  dev_pkgs << "flex"
  dev_pkgs << "dctrl-tools"
  dev_pkgs << "libsctp-dev"
  dev_pkgs << "libxslt1-dev"
  dev_pkgs << "libcap2-bin"
  dev_pkgs << "git"
  dev_pkgs << "ed"

  # dev_pkgs << "build-essential"
  # dev_pkgs << "libtool"
  # dev_pkgs << "autoconf"
  # dev_pkgs << "automake"
  # dev_pkgs << "autoconf-archive"
  # dev_pkgs << "pkg-config"

  # #dev_pkgs << "libssl0.9.8"
  # dev_pkgs << "libssl1.0.0"
  # dev_pkgs << "libssl-dev"
  # dev_pkgs << "zlib1g"
  # dev_pkgs << "zlib1g-dev"
  # dev_pkgs << "libcurl4-openssl-dev"
  # dev_pkgs << "lsb-base"

  # dev_pkgs << "ncurses-dev"
  # dev_pkgs << "libncurses-dev"
  # dev_pkgs << "libmozjs-dev"
  # dev_pkgs << "libmozjs2d"
  # dev_pkgs << "libicu-dev"
  # dev_pkgs << "xsltproc"

  # awkwardly tell ./configure where to find Erlang's headers
  # bitness = node['kernel']['machine'] =~ /64/ ? "lib64" : "lib"
  # compile_flags = "--with-erlang=/usr/#{bitness}/erlang/usr/include"

  bash "aptupdate" do
    code "apt-get -y update; apt-get -y upgrade"
  end

end

# if node['couch_db']['install_erlang']
#   include_recipe "erlang"
# end

dev_pkgs.each do |pkg|
  package pkg
end

# remote_file couchdb_tar_gz do
#   checksum node['couch_db']['src_checksum']
#   source node['couch_db']['buildcouch_src']
# end

git working_dir do
  repository node["couch_db"]["buildcouch_git"]
  reference "master"
  enable_submodules true
  action :sync
end

bash "build couchdb using build-couch package" do
  cwd working_dir
  code <<-EOH
    rake erl_checkout="#{node["couch_db"]["buildcouch_erlang"]}" \
      git="#{node["couch_db"]["buildcouch_couch"]}" \
      plugin="#{node["couch_db"]["buildcouch_couch_xoauth"]}" \
      install="#{build_dir}"
  EOH
  not_if "test -f #{build_dir}/bin/couchdb && #{build_dir}/bin/couchdb -V | grep 'Apache CouchDB #{node['couch_db']['src_version']}'"
  timeout 2*60*60 # ~ 2hr under vbox on my air ;(
end


user "couchdb" do
  home "#{build_dir}/var/lib/couchdb"
  comment "CouchDB Administrator"
  supports :manage_home => false
  system true
end

%w{ var/lib/couchdb var/log/couchdb var/run/couchdb etc/couchdb }.each do |dir|
  directory "#{build_dir}/#{dir}" do
    owner "couchdb"
    group "couchdb"
    mode "0770"
  end
end

template "#{build_dir}/etc/couchdb/local.ini" do
  source "local.ini.erb"
  owner "couchdb"
  group "couchdb"
  mode 0660
  variables(
    :config => node['couch_db']['config']
  )
  notifies :restart, "service[couchdb]"
end

cookbook_file "/etc/init.d/couchdb" do
  source "couchdb.init"
  owner "root"
  group "root"
  mode "0755"
end

bash "fix permissions" do
  code "
    chown -R couchdb:couchdb #{build_dir}/{lib,etc}/couchdb #{build_dir}/var/{lib,log,run}/couchdb
    chmod -R g+rw #{build_dir}/{lib,etc}/couchdb #{build_dir}/var/{lib,log,run}/couchdb
  "
end


service "couchdb" do
  supports [ :restart, :status ]
  action [:enable, :start]
end
