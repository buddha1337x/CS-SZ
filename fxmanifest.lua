fx_version 'cerulean'
game 'gta5'

author 'carson - Classic Scripts'
version '1.0.0'
lua54 'yes'

ui_page 'html/index.html'

shared_script 'client/config.lua'

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
}


files {
    'html/*.*'
}

dependencies {
	'oxmysql',
}
