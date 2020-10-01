@echo off
FOR /F %%p IN (libs.txt) DO (
	echo %%p
	START /W /B python -c "import %%p"
)