FROM centos

RUN yum update -y && \
    yum clean all

RUN yum install -y git && \
    yum install wget -y && \
    yum install -y openssh-server && \
    yum install -y java-1.8.0-openjdk && \
    yum install -y sudo && \
    yum clean all

# Generate dummy keys -- CentOS doesn't auto-generate them like Ubuntu does :(
RUN /usr/bin/ssh-keygen -A

# Set SSH configuration to allow remote logins without /proc write access
RUN sed -ri 's/^session\s+required\s+pam_loginuid.so$/session optional pam_loginuid.so/' /etc/pam.d/sshd

# Create Jenkins User
RUN useradd jenkins -m -s /bin/bash

# Add public key for Jenkins login
RUN mkdir /home/jenkins/.ssh
COPY /files/authorized_keys /home/jenkins/.ssh/authorized_keys
RUN chown -R jenkins /home/jenkins
RUN chgrp -R jenkins /home/jenkins
RUN chmod 600 /home/jenkins/.ssh/authorized_keys
RUN chmod 700 /home/jenkins/.ssh

# Add the jenkins user to sudoers
RUN echo "jenkins ALL=(ALL) ALL" >> etc/sudoers

# Set name servers
COPY /files/resolv.conf /etc/resolv.conf

# Expose SSH port and run SSHD
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]