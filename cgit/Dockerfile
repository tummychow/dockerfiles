FROM tummychow/archlinux:2015.07.03

RUN pacman -S --noconfirm nginx cgit fcgiwrap spawn-fcgi highlight

ADD nginx.conf /etc/nginx/nginx.conf

CMD spawn-fcgi -u http -s /run/fcgiwrap.sock -- /usr/bin/fcgiwrap -f && exec nginx
EXPOSE 80
