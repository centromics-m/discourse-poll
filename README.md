## New Poll 
  Correct Option And Front Main Summary Link 

## Installation

1. docker
Edit container/app.yml

hooks:
after_code:
- exec:
  cd: $home/plugins
  cmd:
- rm -Rf poll
- git clone -b develop https://github.com/centromics-m/discourse-poll.git poll


2. Source

cd $home/plugins
rm -Rf poll
git clone -b develop https://github.com/centromics-m/discourse-poll.git poll
cd $home
bundle exec rake db:migrate

## How to use



## Screenshots


## Read More



## License

GPL
