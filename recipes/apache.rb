#
# Author:: Yury Proshchenko <spect.man@gmail.com>
# Cookbook Name:: couchdb
# Recipe:: apache
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

if node['platform'] == "ubuntu" && node['platform_version'].to_f == 8.04
  log "Ubuntu 8.04 does not supply sufficient development libraries via APT to install CouchDB #{node['couch_db']['src_version']} from source."
  return
end

couch_filename = node['couch_db']['src_filename'] or "apache-couchdb-#{node['couch_db']['src_version']}"
couchdb_tar_gz = File.join(Chef::Config[:file_cache_path], "/", "#{couch_filename}.tar.gz")
compile_flags = String.new


package "build-essential"
package "erlang-base-hipe"
package "erlang-dev"
package "erlang-manpages"
package "erlang-eunit"
package "erlang-nox"
package "libicu-dev"
package "libmozjs185-1.0"
package "libmozjs185-dev"
#package "libmozjs-dev"
package "libcurl4-openssl-dev"
package "pkg-config"


# awkwardly tell ./configure where to find Erlang's headers
# bitness = node['kernel']['machine'] =~ /64/ ? "lib64" : "lib"
# compile_flags = "--with-erlang=/usr/#{bitness}/erlang/usr/include"


if node['couch_db']['install_erlang']
  include_recipe "erlang"
end

remote_file couchdb_tar_gz do
  checksum node['couch_db']['src_checksum']
  source node['couch_db']['src_mirror']
end

bash "install couchdb #{node['couch_db']['src_version']}" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    tar -zxf #{couchdb_tar_gz}
    cd #{couch_filename}
    ./bootstrap
    ./configure #{compile_flags}
    make && make install
  EOH
  not_if "test -f /usr/local/bin/couchdb && /usr/local/bin/couchdb -V | grep 'Apache CouchDB #{node['couch_db']['src_version']}'"
end

user "couchdb" do
  home "/usr/local/var/lib/couchdb"
  comment "CouchDB Administrator"
  supports :manage_home => false
  system true
end

bash "fix permissions" do
  code "
    chown -R couchdb:couchdb /usr/local/{lib,etc}/couchdb /usr/local/var/{lib,log,run}/couchdb
    chmod -R g+rw /usr/local/{lib,etc}/couchdb /usr/local/var/{lib,log,run}/couchdb
  "
end

template "/usr/local/etc/couchdb/local.ini" do
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

service "couchdb" do
  supports [ :restart, :status ]
  action [:enable, :start]
end

