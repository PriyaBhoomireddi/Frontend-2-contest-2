function validateEmail() {
    const emailInput = document.getElementById("email");
    const emailError = document.getElementById('email-error');
    const emailValue = emailInput.value;
  
    if (emailValue.length > 3 && emailValue.includes('@') && emailValue.includes('.')) {
      emailError.style.display = 'none';
      return true;
    } else {
      emailError.style.display = 'block';
      return false;
    }
  }
  
  
  function validatePassword() {
    const passwordInput = document.getElementById('password');
    const passwordError = document.getElementById('password-error');
    const passwordValue = passwordInput.value;
  
    if (passwordValue.length > 8) {
      passwordError.style.display = 'none';
      return true;
    } else {
      passwordError.style.display = 'block';
      return false;
    }
  }
  
  function handleSubmit(event) {
    event.preventDefault();
    const emailValid = validateEmail();
    const passwordValid = validatePassword();
  
    const successMessage = document.getElementById('success-message');
    const formTitle = document.getElementById('form-title');
  
    if (emailValid && passwordValid) {
      successMessage.style.display = 'block';
      formTitle.textContent = 'If validations are correct!';
  
      if (confirm("Do you want to submit the form?")) {
        alert("Successful signup!");
        document.getElementById('signup-form').reset();
      } else {
        document.getElementById('signup-form').reset();
      }
    } else {
      successMessage.style.display = 'none';
      formTitle.textContent = "If validations aren't correct!";
    }
  }
  