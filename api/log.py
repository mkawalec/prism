from . import app
import logging
from logging import (Formatter, getLogger,
        FileHandler)
from logging.handlers import (SMTPHandler,
        RotatingFileHandler)

ADMINS = ['michal@bazzle.me']
loggers = [app.logger, getLogger('sqlalchemy')]

class TlsSMTPHandler(SMTPHandler):
    def emit(self, record):
        """
        Emit a record.
 
        Format the record and send it to the specified addressees.
        """
        try:
            import smtplib
            import string # for tls add this line
            try:
                from email.utils import formatdate
            except ImportError:
                formatdate = self.date_time
            port = self.mailport
            if not port:
                port = smtplib.SMTP_PORT
            smtp = smtplib.SMTP(self.mailhost, port)
            msg = self.format(record)
            msg = "From: %s\r\nTo: %s\r\nSubject: %s\r\nDate: %s\r\n\r\n%s" % (
                            self.fromaddr,
                            string.join(self.toaddrs, ","),
                            self.getSubject(record),
                            formatdate(), msg)
            if self.username:
                smtp.ehlo() # for tls add this line
                smtp.starttls() # for tls add this line
                smtp.ehlo() # for tls add this line
                smtp.login(self.username, self.password)
            smtp.sendmail(self.fromaddr, self.toaddrs, msg)
            smtp.quit()
        except (KeyboardInterrupt, SystemExit):
            raise
        except:
            self.handleError(record)

if not app.debug:
    mail_handler = TlsSMTPHandler(("bez-inwigilacji.pl", 587), 
            'no-reply@bez-inwigilacji.pl', ADMINS, 
            '[bez-inwigilacji] App failed!', 
            ('no-reply@bez-inwigilacji.pl', 'a2dc34'))
    mail_handler.setFormatter(Formatter('''
    Message type:       %(levelname)s
    Location:           %(pathname)s:%(lineno)d
    Module:             %(module)s
    Function:           %(funcName)s
    Time:               %(asctime)s

    Message:

    %(message)s
    '''))
    mail_handler.setLevel(logging.ERROR)

    file_handler = FileHandler('warning.log')
    file_handler.setLevel(logging.WARNING)
    file_handler.setFormatter(Formatter(
        '%(asctime)s %(levelname)s: %(message)s '
        '[in %(pathname)s:%(lineno)d]'
    ))

    for logger in loggers:
        app.logger.addHandler(mail_handler)
        app.logger.addHandler(file_handler)

else:
    file_handler = RotatingFileHandler('debug.log',
            maxBytes=1024)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(Formatter(
        '%(asctime)s %(levelname)s: %(message)s '
        '[in %(pathname)s:%(lineno)d]'
    ))
    for logger in loggers:
        logger.addHandler(file_handler)
        logger.setLevel(logging.INFO)
        

