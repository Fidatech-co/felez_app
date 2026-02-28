for sending any request we use JWT bearinng
flow of data:
    1- login part has:
        1- login by number+pass
        2- login with OTP button
        3- forget pass button
            1- get the number and send call the opt
            2- enter otp then enter acc
    - get the login data ad store it in profile part  
    - dont connect the notification service yet
    - we take the time date when a form is filled when a form is filled if we have network connection we send it to the server if not we save it and then send it when we have network connection automaticly
    - when seding the form through api we send the created at and modified at
    - users have
     access to some of forms not all of them so we must check the users access to the forms and show only the forms they have access to
    - app is for offline usage so when we log in sync with the database and get the latest data that are needed for the forms
    - if when we are offline db changes the form but we used the last state that is not feasible anymore let the user change the state to the new one or delete its request
    - some of the values of forms are enumn which must be defined on client side
    - we must cach the server db in client side
    - make a db in client side and store the data it entered
    - if a data passed the 15day marking delete it from client db so the app does not get heavy
    - show the syncing with server in the hader to user
    - showt the last 15 day forms that entered and their value to the user