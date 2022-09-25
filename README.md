# rcell-smsclient
SMS client for the Multicom MultiConnect rCell 100

Usage: smsclient.pl -p number

    Takes SMS content on standard input and sends on EOF

    Required options:
    -p  Phone number to send SMS to

    Other options:
    -v  Verbose mode
    -h  Show this help message

    Example:
    echo "test message" | smsclient.pl -p 9995550100

    Developed for the Multicom MultiConnect rCell 100
    https://github.com/WillCodeForCats/rcell-smsclient

# MultiConnect® rCell 100 Series
https://www.multitech.com/brands/multiconnect-rcell-100-series
