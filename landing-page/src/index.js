import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import Logo from './assets/logo.svg';
import MainImage from './assets/main-image.svg';

function Header() {
  return (
    <header className="site-header" role="banner">
      <div className="container header-inner">
        <img src={Logo} alt="عين - شعار" className="logo" />
        <nav aria-label="القائمة الرئيسية">
          <a href="#features" className="nav-link">المزايا</a>
          <a href="#methodology" className="nav-link">المنهجية</a>
          <a href="#get-started" className="nav-link cta">ابدأ الآن</a>
        </nav>
      </div>
    </header>
  );
}

function Hero() {
  return (
    <section className="hero" id="home" role="region" aria-labelledby="hero-title">
      <div className="container hero-inner">
        <div className="hero-text">
          <h1 id="hero-title">عين — رفيقك الذكي للرؤية</h1>
          <p className="lead">تطبيق متقدم مدعوم بالذكاء الاصطناعي لمساعدة المكفوفين وذوي الإعاقة البصرية في التفاعل مع العالم بكل ثقة.</p>
          <div className="hero-ctas">
            <a className="btn primary" href="#get-started">جرّبه الآن</a>
            <a className="btn ghost" href="#methodology">تعرف على المنهجية</a>
          </div>
          <ul className="trust-list" aria-hidden>
            <li>WCAG 2.1 AA</li>
            <li>متعدد اللغات</li>
            <li>استجابة فورية</li>
          </ul>
        </div>
        <div className="hero-media" aria-hidden>
          <img src={MainImage} alt="عرض التطبيق" />
        </div>
      </div>
    </section>
  );
}

function Features() {
  return (
    <section id="features" className="features" role="region" aria-labelledby="features-title">
      <div className="container">
        <h2 id="features-title">مزايا رئيسية</h2>
        <div className="features-grid">
          <article className="feature">
            <h3>كشف الأشياء في الزمن الحقيقي</h3>
            <p>نظام رؤية حاسوبية سريع ودقيق يحدد الأشخاص والعناصر والعقبات حول المستخدم.</p>
          </article>
          <article className="feature">
            <h3>قراءة النصوص (OCR)</h3>
            <p>التعرّف على النصوص في الصور متعدد اللغات مع إخراج قابل للقراءة صوتياً.</p>
          </article>
          <article className="feature">
            <h3>أوامر صوتية واستجابة ناطقة</h3>
            <p>واجهة صوتية ذكية تسمح بالتفاعل الفوري وإعطاء تعليمات للمستخدم.</p>
          </article>
          <article className="feature">
            <h3>التشغيل دون اتصال</h3>
            <p>وضع محدود دون اتصال يتيح وظائف أساسية عندما لا تتوفر شبكة الإنترنت.</p>
          </article>
        </div>
      </div>
    </section>
  );
}

function Methodology() {
  return (
    <section id="methodology" className="methodology" role="region" aria-labelledby="methodology-title">
      <div className="container">
        <h2 id="methodology-title">منهجية العمل</h2>
        <ol className="method-steps">
          <li>
            <strong>بحث المستخدم والاحتياجات:</strong>
            <p>جمع متطلبات المستخدمين ذوي الإعاقة بالتعاون مع مؤسسات ذوي الإعاقة واختبار استخدام ميداني.</p>
          </li>
          <li>
            <strong>تصميم شامل وقابلية الوصول:</strong>
            <p>تصميم واجهات متوافقة مع معايير WCAG وتوفير تجارب صوتية وتهتكية.</p>
          </li>
          <li>
            <strong>نماذج AI قابلة للتوسع:</strong>
            <p>تدريب ونشر نماذج رؤية ونص مع مراعاة الأداء والخصوصية.</p>
          </li>
          <li>
            <strong>نشر موثوق ومراقبة:</strong>
            <p>نشر عبر Kubernetes مع مراقبة Prometheus وGrafana واختبارات مستمرة.</p>
          </li>
        </ol>
      </div>
    </section>
  );
}

function GetStarted() {
  return (
    <section id="get-started" className="get-started" role="region" aria-labelledby="get-started-title">
      <div className="container">
        <h2 id="get-started-title">ابدأ اليوم</h2>
        <p>اختر كيفية البدء: تنزيل التطبيق، تجربة الويب، أو التواصل للحصول على عرض تجريبي للمؤسسات.</p>
        <div className="ctas">
          <a className="btn primary" href="/downloads">تنزيل التطبيق</a>
          <a className="btn ghost" href="mailto:enterprise@vision-assistant.com">طلب عرض تجريبي</a>
        </div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="site-footer" role="contentinfo">
      <div className="container">
        <p>© {new Date().getFullYear()} Vision Assistant — جميع الحقوق محفوظة.</p>
        <nav aria-label="روابط تذييل">
          <a href="/docs">التوثيق</a>
          <a href="/privacy">الخصوصية</a>
          <a href="/contact">اتصل بنا</a>
        </nav>
      </div>
    </footer>
  );
}

function App() {
  return (
    <div className="app" lang="ar" dir="rtl">
      <a className="skip-link" href="#main">تخطي إلى المحتوى</a>
      <Header />
      <main id="main">
        <Hero />
        <Features />
        <Methodology />
        <GetStarted />
      </main>
      <Footer />
    </div>
  );
}

const root = createRoot(document.getElementById('root'));
root.render(<App />);
