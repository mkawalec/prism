if __name__ == '__main__':
    from api import app
    
    app.debug = True
    app.run(debug=True)
