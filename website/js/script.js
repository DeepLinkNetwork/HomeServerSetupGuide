// JavaScript functionality for the Home Server Setup Guide website

document.addEventListener('DOMContentLoaded', function() {
    // Smooth scrolling for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            const targetElement = document.querySelector(targetId);
            
            if (targetElement) {
                window.scrollTo({
                    top: targetElement.offsetTop - 70,
                    behavior: 'smooth'
                });
            }
        });
    });

    // Active navigation highlighting
    const sections = document.querySelectorAll('section');
    const navLinks = document.querySelectorAll('nav ul li a');
    
    window.addEventListener('scroll', () => {
        let current = '';
        
        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.clientHeight;
            
            if (pageYOffset >= sectionTop - 100) {
                current = section.getAttribute('id');
            }
        });
        
        navLinks.forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === `#${current}`) {
                link.classList.add('active');
            }
        });
    });

    // Documentation sidebar functionality
    const docLinks = document.querySelectorAll('.doc-sidebar a');
    
    docLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            // Remove active class from all links
            docLinks.forEach(l => l.classList.remove('active'));
            
            // Add active class to clicked link
            this.classList.add('active');
            
            // If we're on a small screen, scroll the sidebar into view
            if (window.innerWidth < 768) {
                this.scrollIntoView({
                    behavior: 'smooth',
                    block: 'nearest'
                });
            }
        });
    });

    // Mobile navigation toggle
    const createMobileNav = () => {
        if (!document.querySelector('.mobile-nav-toggle')) {
            const nav = document.querySelector('nav');
            const mobileToggle = document.createElement('button');
            mobileToggle.classList.add('mobile-nav-toggle');
            mobileToggle.innerHTML = '<i class="fas fa-bars"></i>';
            nav.querySelector('.container').prepend(mobileToggle);
            
            mobileToggle.addEventListener('click', () => {
                const navList = nav.querySelector('ul');
                navList.classList.toggle('show');
                
                if (navList.classList.contains('show')) {
                    mobileToggle.innerHTML = '<i class="fas fa-times"></i>';
                } else {
                    mobileToggle.innerHTML = '<i class="fas fa-bars"></i>';
                }
            });
        }
    };

    // Call mobile nav function if screen width is below 768px
    if (window.innerWidth < 768) {
        createMobileNav();
    }

    // Recalculate on resize
    window.addEventListener('resize', () => {
        if (window.innerWidth < 768) {
            createMobileNav();
        }
    });

    // Code block copy functionality
    document.querySelectorAll('pre').forEach(block => {
        const copyButton = document.createElement('button');
        copyButton.className = 'copy-button';
        copyButton.textContent = 'Copy';
        
        block.style.position = 'relative';
        block.appendChild(copyButton);
        
        copyButton.addEventListener('click', () => {
            const code = block.querySelector('code').innerText;
            navigator.clipboard.writeText(code).then(() => {
                copyButton.textContent = 'Copied!';
                setTimeout(() => {
                    copyButton.textContent = 'Copy';
                }, 2000);
            });
        });
    });
});
