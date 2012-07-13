require 'rubygems'
require 'mechanize'

@cookie_file = './icoke_cookie.txt'
@display_log = true

# Ensure the config file exists and all variables exist.
unless File.exists?('./config.rb')
    puts <<-eos
Missing config file. Please rename the example.config.rb file to config.rb and 
set your icoke email and password. If your missing the example config it should
look like this:

@email       = 'your-email'
@password    = 'your-password'
    eos
    exit!
else
    require './config.rb'
end

def log msg, display_log = true    
    display_log = false if @display_log === false
    puts msg if display_log
end

def reset_cookie
    File.delete @cookie_file if File.exists?(@cookie_file)
end

def icoke_login agent
    unless File.exists?(@cookie_file)
        log ' - Requesting login page.'
        login_form  = agent.get('https://secure.icoke.ca/account/login').forms.first

        login_form.emailAddress = @email
        login_form.password     = @password

        login_form.checkbox_with(:name => 'rememberMe').check

        log ' - Submitting login form.'
        login_result = login_form.submit

        # Check to see the login failed.
        errors = login_result.search('//*[@id="loginModel.errors"]')
        unless errors.empty?
            puts errors.text
            exit!
        end

        # Save Cookie to file.
        log ' - Saving cookie to file.'
        File.open(@cookie_file, "w") do |file|
            agent.cookie_jar.dump_cookiestxt(file)
        end
    else
        log ' - Load cookie file.'
        agent.cookie_jar.load(@cookie_file, :cookiestxt)

        log ' - Checking if cookie is valid.'
        unless agent.get('https://secure.icoke.ca/pin').search('//*[@id="loginModel"]').empty?
            log ' - Cookie is not valid. Initializing login.'
            reset_cookie
            icoke_login agent
        end
    end
end

pin         = ARGV.shift

# If pin equals reset then delete the cookie file.
if pin === 'reset'
    reset_cookie
    puts 'Cookie file has been deleted, reset successful.'
    exit!
end

# Make sure a pin in present and that it's atleast 10 characters.
if pin.nil? || pin.length < 10
    puts 'Please enter a pin greater than 10 characters.'
    exit!
end

agent       = Mechanize.new

icoke_login agent

log ' - Requesting pin page.'
pin_page    = agent.get('https://secure.icoke.ca/pin')
pnts_before = pin_page.search('//*[@id="balance"]/h2').text
name        = pin_page.search('//*[@id="points"]/h3').text
pin_form    = pin_page.forms.first
pin_form.pin= pin

log ' - Submitting pin form.'
pin_results = pin_form.submit

pnts_after  = pin_results.search('//*[@id="balance"]/h2').text

search_success  = pin_results.search('//*[@class="completeText"]')
search_fail     = pin_results.search('//*[@id="pinInfo.errors"]')

unless search_success.empty?
    puts search_success.text
    puts "\n#{name} had #{pnts_before} and now has #{pnts_after}"
end

unless search_fail.empty?
    puts search_fail.text
end