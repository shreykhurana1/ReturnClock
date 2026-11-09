# ReturnClock

ReturnClock is a Ruby on Rails application for tracking purchases and return deadlines. Users can create store return policies, add and manage purchases, and view upcoming returns and purchase history.

Deployed app: [https://returnclock-a408217a60ef.herokuapp.com/](https://returnclock-a408217a60ef.herokuapp.com/)


## Team Members

Member 1 Name: Ryan Shi\
Member 1 UNI: rs4469\
Member 2 Name: Jordan Wu\
Member 2 UNI: xw2970\
Member 3 Name: Shrey Khurana\
Member 3 UNI: sk5662\
Member 4 Name: Sophia Ling\
Member 4 UNI: sl4909


## Setup

**Requirements:** Ruby 3.3.12, Bundler 2.5.22, PostgreSQL 18, Git, and libvips.

**macOS (Homebrew):**

```bash
brew install git rbenv ruby-build postgresql@18 vips
brew services start postgresql@18
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
```

**Windows (WSL Ubuntu):**

Install PostgreSQL 18 using the [official instructions](https://www.postgresql.org/download/linux/ubuntu/), then install the required dependencies:

```bash
sudo apt update
sudo apt install -y build-essential git libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libpq-dev libvips-dev
sudo service postgresql start
```

On WSL, ensure your Linux username has a PostgreSQL role with `CREATEDB` privileges. If the role is missing:

```bash
sudo -u postgres createuser --createdb "$(whoami)"
```

Install and configure [rbenv](https://github.com/rbenv/rbenv#installation), then install Ruby 3.3.12.

**Run the application:**

```bash
git clone https://github.com/shreykhurana1/ReturnClock.git
cd ReturnClock
gem install bundler -v 2.5.22
bundle install
bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
bin/rails server
```

Open http://localhost:3000.

## Tests

```bash
bundle exec rspec
bin/rails test
bundle exec cucumber
```

## Contributing

Create a feature branch from the latest `main`, implement your changes, and run the tests before pushing.

```bash
git switch main
git pull origin main
git switch -c your-name/feature-name
```

Commit and push your changes, then open a pull request into `main`. Wait for GitHub Actions checks to pass before merging.

When working with user-specific data, use `Current.user` to scope database queries.