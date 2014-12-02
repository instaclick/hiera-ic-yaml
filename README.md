# hiera-ic-yaml

[![Build Status](https://travis-ci.org/instaclick/hiera-ic-yaml.png?branch=master)](https://travis-ci.org/instaclick/hiera-ic-yaml)

[![Gem Version](https://badge.fury.io/rb/hiera-ic-yaml.svg)](http://badge.fury.io/rb/hiera-ic-yaml)

A Hiera yaml backend that support imports


## Installation

#### This gem requires hiera = 1.3.0


`gem install hiera-ic-yaml`

or

`rake gem`

`gem install --local /path-to/pkg/hiera-ic-yaml-{version}.gem`


## Configuration
Here is a sample hiera.yaml file that will work with ic_yaml


`cat /etc/puppet/hiera.yaml`
```yaml
:backends:
  - 'ic_yaml'

:hierarchy:
    - %{::environment}/%{::role}
    - %{::role}

:ic_yaml:
  :datadir: '/etc/puppet/nodes'
  :imports_key: 'imports'
```


`cat /etc/puppet/hieradata/role1.yaml`
```yaml
---
imports:
    - "class1.yaml"
    - "class2.yaml"

classes:
    - class1
    - class2
```
