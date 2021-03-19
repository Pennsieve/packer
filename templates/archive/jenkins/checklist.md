# Checklist

## To Do

- EC Instance
  - 8 GB SSD
  - 500 GB
    - Mount to /data
- Jenkins User
  - Add authorized\_key
  - Add user to Docker group
- Jenkins Config
  - EnvInject Plugin
  - Configure env vars to use env file created in step 1.d
  - SSH Slave
    - Add keys

## Not Done

### AWS CLI

Allow cloudfront preview: add following to .aws/config

```
[preview]
cloudfront = true
```

### Docker DNS Gen

See option 3: https://github.com/Blackfynn/blackfynn-pipeline/tree/dev/images/test-hbase

### Bash Profile

Add `~/.bash\_profile` to `~/.bashrc`

```
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/go/bin

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
```
