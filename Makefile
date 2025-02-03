fmt:
	echo "===> Formatting"
	stylua lua/ --config-path=.stylua.toml

lint:
	echo "===> Linting"
	luacheck lua/ --globals vim

clean:
	echo "===> Cleaning"
	rm /tmp/lua_*
