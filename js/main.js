/* ============================================
   Townsend Bros Construction Co Ltd
   Main JavaScript
   ============================================ */

(function () {
    'use strict';

    // --- Navigation scroll behaviour ---
    const nav = document.getElementById('nav');
    const navToggle = document.getElementById('nav-toggle');
    const navLinks = document.getElementById('nav-links');

    function handleNavScroll() {
        if (window.scrollY > 80) {
            nav.classList.add('scrolled');
        } else {
            nav.classList.remove('scrolled');
        }
    }

    window.addEventListener('scroll', handleNavScroll, { passive: true });
    handleNavScroll();

    // --- Mobile menu toggle ---
    navToggle.addEventListener('click', function () {
        navToggle.classList.toggle('active');
        navLinks.classList.toggle('active');
        document.body.style.overflow = navLinks.classList.contains('active') ? 'hidden' : '';
    });

    // Close mobile menu on link click
    navLinks.querySelectorAll('a').forEach(function (link) {
        link.addEventListener('click', function () {
            navToggle.classList.remove('active');
            navLinks.classList.remove('active');
            document.body.style.overflow = '';
        });
    });

    // --- Hero slideshow ---
    var slides = document.querySelectorAll('.hero-slide');
    var currentSlide = 0;

    function nextSlide() {
        slides[currentSlide].classList.remove('active');
        currentSlide = (currentSlide + 1) % slides.length;
        slides[currentSlide].classList.add('active');
    }

    if (slides.length > 1) {
        setInterval(nextSlide, 6000);
    }

    // --- Scroll-triggered fade-in animations ---
    function initScrollAnimations() {
        var elements = document.querySelectorAll(
            '.section-header, .project-card, .profile-image, .profile-content, ' +
            '.service-card, .client-item, .contact-info, .contact-form, .parallax-content'
        );

        elements.forEach(function (el) {
            el.classList.add('fade-in');
        });

        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (entry.isIntersecting) {
                    entry.target.classList.add('visible');
                    observer.unobserve(entry.target);
                }
            });
        }, {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        });

        elements.forEach(function (el) {
            observer.observe(el);
        });
    }

    if ('IntersectionObserver' in window) {
        initScrollAnimations();
    }

    // --- Contact form (front-end only) ---
    var form = document.getElementById('contact-form');
    if (form) {
        form.addEventListener('submit', function (e) {
            e.preventDefault();
            var btn = form.querySelector('.btn-submit');
            var originalText = btn.textContent;
            btn.textContent = 'Message Sent!';
            btn.style.background = '#2d5039';
            btn.disabled = true;

            setTimeout(function () {
                btn.textContent = originalText;
                btn.style.background = '';
                btn.disabled = false;
                form.reset();
            }, 3000);
        });
    }

    // --- Smooth scroll for anchor links ---
    document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
        anchor.addEventListener('click', function (e) {
            var target = document.querySelector(this.getAttribute('href'));
            if (target) {
                e.preventDefault();
                var offset = parseInt(getComputedStyle(document.documentElement)
                    .getPropertyValue('--nav-height')) || 72;
                var top = target.getBoundingClientRect().top + window.pageYOffset - offset;
                window.scrollTo({ top: top, behavior: 'smooth' });
            }
        });
    });

})();
