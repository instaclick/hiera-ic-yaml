Installation
============

`gem install hiera-ic-yaml`

or

`rake gem`
`gem install --local /path-to/pkg/hiera-ic-yaml-{version}.gem`


Configuration
=============
Here is a sample hiera.yaml file that will work with ic_yaml and fall back to yaml


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
