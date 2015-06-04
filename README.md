# OpenStreetMap.app prototype

This is an experiment in the principle of a "smart editor" for iPhone - a program for contributing to OpenStreetMap with minimal effort on the part of the user.

The app uses speech dictation to make surveying addresses simple and fast.

## How to use it

Before using the app, go to the Settings app, select the OpenStreetMap settings, and enter your username and password.

1. Go to the street you want to survey.
2. Open the app and select the 'Addresses' tab. ('Map' doesn't do anything right now.)
3. Start walking.
4. When it gets a GPS fix, it'll find the nearest street name and populate the field. (If you want to change this at any time, hit 'Refresh'.)
5. When you come to a house number you want to survey, say 'LEFT THREE' (i.e. no. 3 is on your left) or 'RIGHT EIGHTEEN' (no. 18 is on your left).
6. The app will repeat the text back to you to confirm it has understood.
7. If it makes a mistake, say 'DELETE LAST'.
8. Repeat until you're done.
9. To upload the addresses, say 'SAVE ADDRESSES'.

You'll need to speak deliberately and loudly. It usually helps if you stop walking when dictating.

## About the code

This is a quick and simple experiment. Everything that could be omitted is omitted. There is lots of bad practice (hello, basic auth). The code is liberally sprinkled with asterisked todos. Do not use this for serious mapping and certainly not as an example of good code. But use it as a pointer to what could be done.

It's written in Swift (!!?!!!!?) and you'll need Xcode to build it, of course.

Speech recognition is carried out by OpenEars. Street name lookup is via Overpass API.

## Licence

FTWPL. You may do anything you like with this code and there is no flaming warranty.
