#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
require 'json'

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'grafana'))

Puppet::Type.type(:grafana_datasource).provide(:grafana, parent: Puppet::Provider::Grafana) do
  desc 'Support for Grafana datasources'

  defaultfor kernel: 'Linux'

  def organization
    response = send_request('GET', "/api/orgs/name/#{@organization}")
    if response.code != '200'
      raise format('Failed to retrieve organization %s (HTTP response: %s/%s)', name, response.code, response.body)
    end

    begin
      organization = JSON.parse(response.body)
      {
        :name => organization["name"],
        :id => organization["id"],
      }
    end
  rescue JSON::ParserError
    raise format('Failed to parse response: %s', response.body)
  end

  def datasources
    response = send_request('GET', '/api/datasources')
    if response.code != '200'
      raise format('Fail to retrieve datasources (HTTP response: %s/%s)', response.code, response.body)
    end

    begin
      datasources = JSON.parse(response.body)

      datasources.map { |x| x['id'] }.map do |id|
        response = send_request 'GET', format('/api/datasources/%s', id)
        if response.code != '200'
          raise format('Failed to retrieve datasource %d (HTTP response: %s/%s)', id, response.code, response.body)
        end

        datasource = JSON.parse(response.body)

        {
          :id => datasource["id"],
          :name => datasource["name"],
          :org_id => organization["orgId"],
          :url => datasource["url"],
          :type => datasource["type"],
          :user => datasource["user"],
          :password => datasource["password"],
          :database => datasource["database"],
          :access_mode => datasource["access"],
          :is_default => datasource["isDefault"] ? :true : :false,
          :with_credentials => datasource["withCredentials"] ? :true : :false,
          :basic_auth => datasource["basicAuth"] ? :true : :false,
          :basic_auth_user => datasource["basicAuthUser"],
          :basic_auth_password => datasource["basicAuthPassword"],
          :json_data => datasource["jsonData"],
        }      
      end
    rescue JSON::ParserError
      raise format('Failed to parse response: %s', response.body)
    end
  end

  def datasource
    unless @datasource
      @datasource = datasources.find { |x| x[:name] == resource[:name] }
    end
    @datasource
  end

  attr_writer :datasource

  def org_id
    organization[:id]
  end
  
  def org_id=(value)
    resource[:org_id] = value
    save_datasource
  end

  def type
    datasource[:type]
  end

  def type=(value)
    resource[:type] = value
    save_datasource
  end

  def url
    datasource[:url]
  end

  def url=(value)
    resource[:url] = value
    save_datasource
  end

  def access_mode
    datasource[:access_mode]
  end

  def access_mode=(value)
    resource[:access_mode] = value
    save_datasource
  end

  def database
    datasource[:database]
  end

  def database=(value)
    resource[:database] = value
    save_datasource
  end

  def user
    datasource[:user]
  end

  def user=(value)
    resource[:user] = value
    save_datasource
  end

  def password
    datasource[:password]
  end

  def password=(value)
    resource[:password] = value
    save_datasource
  end

  # rubocop:disable Style/PredicateName
  def is_default
    datasource[:is_default]
  end

  def is_default=(value)
    resource[:is_default] = value
    save_datasource
  end
  # rubocop:enable Style/PredicateName

  def basic_auth
    self.datasource[:basic_auth]
  end

  def basic_auth=(value)
    resource[:basic_auth] = value
    self.save_datasource()
  end

  def basic_auth_user
    self.datasource[:basic_auth_user]
  end

  def basic_auth_user=(value)
    resource[:basic_auth_user] = value
    self.save_datasource()
  end

  def basic_auth_password
    self.datasource[:basic_auth_password]
  end

  def basic_auth_password=(value)
    resource[:basic_auth_password] = value
    self.save_datasource()
  end

  def with_credentials
    self.datasource[:is_default]
  end

  def with_credentials=(value)
    resource[:with_credentials] = value
    self.save_datasource()
  end

  def json_data
    datasource[:json_data]
  end

  def json_data=(value)
    resource[:json_data] = value
    save_datasource
  end

  def save_datasource
    data = {
      :name => resource[:name],
      :orgId => resource[:org_id],
      :type => resource[:type],
      :url => resource[:url],
      :access => resource[:access_mode],
      :database => resource[:database],
      :user => resource[:user],
      :password => resource[:password],
      :isDefault => (resource[:is_default] == :true),
      :withCredentials => (resource[:with_credentials] == :true),
      :jsonData => resource[:json_data],
    }

    if resource[:basic_auth]
      data[:basicAuth] = resource[:basic_auth]
      data[:basicAuthUser] = resource[:basic_auth_user]
      data[:basicAuthPassword] = resource[:basic_auth_password]
    end

    if datasource.nil?
      response = send_request('POST', '/api/datasources', data)
    else
      data[:id] = datasource[:id]
      response = send_request 'PUT', format('/api/datasources/%s', datasource[:id]), data
    end

    if response.code != '200'
      raise format('Failed to create save %s (HTTP response: %s/%s)', resource[:name], response.code, response.body)
    end
    self.datasource = nil
  end

  def delete_datasource
    response = send_request 'DELETE', format('/api/datasources/%s', datasource[:id])

    if response.code != '200'
      raise format('Failed to delete datasource %s (HTTP response: %s/%s', resource[:name], response.code, response.body)
    end
    self.datasource = nil
  end

  def create
    save_datasource
  end

  def destroy
    delete_datasource
  end

  def exists?
    datasource
  end
end
