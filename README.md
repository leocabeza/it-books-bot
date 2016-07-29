# it-books-bot
Search and download books from Telegram

# Add me on Telegram: [@itbooksbot](https://telegram.me/itbooksbot)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/leocabeza/it-books-bot. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

### Running the bot
For the first you need to install gems required to start the bot:

```sh
bundle install
```

Then you need to create `secrets.yml` where your bot unique token will be stored and `database.yml` where database credentials will be stored. I've already created samples for you, so you can easily do:

```sh
cp config/database.yml.sample config/database.yml
cp config/secrets.yml.sample config/secrets.yml
```

Then you need to fill your [Telegram bot unique token](https://core.telegram.org/bots#botfather) to the `secrets.yml` file and your database credentials to `database.yml`.

After this you need to create and migrate your database:

```sh
rake db:create db:migrate
```

Great! Now you can easily start your bot just by running this command:

```sh
bin/bot
```