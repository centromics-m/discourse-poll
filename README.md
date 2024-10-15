## New Poll 
 correct answer, management function and provides main page summary link

## Installation

1. docker   
  Edit container/app.yml
``` dockerfile
hooks:
after_code:
- exec:
  cd: $home/plugins
  cmd:
- rm -Rf poll
- git clone -b develop https://github.com/centromics-m/discourse-poll.git poll
```

2. Source

``` shell
$ cd $home/plugins
$ rm -Rf poll
$ git clone -b develop https://github.com/centromics-m/discourse-poll.git poll
$ cd $home
$ bundle exec rake db:migrate
```

## How to use



## Screenshots


## Read More



## License

GPLv2
