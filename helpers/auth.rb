require 'bcrypt'

class Auth

  def self.hash_password(password)
    BCrypt::Password.create(password).to_s
  end

  def self.test_password(password, hash)
    BCrypt::Password.new(hash) == password
  end

  def self.generate_password
    # pick a random word
    adjectives = ['happy', 'silly', 'proud', 'plain', 'clean', 'tiny', 'scary', 'clumsy', 'grumpy', 'brave', 'huge', 'jolly', 'calm', 'silly', 'fancy']
    nouns = ['desk', 'paper', 'staples', 'light', 'phone', 'pencil', 'eraser', 'glass', 'stand', 'sushi', 'kitten', 'bear', 'bulb', 'dancer', 'speaker']
    adj = adjectives.sample
    noun = nouns.sample

    # generate a 4 digit number
    number = rand(1000..9999)
    number_string = number.to_s

    # combine to make password
    password = adj + noun + number_string

    return password
  end

end
