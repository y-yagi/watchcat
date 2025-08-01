use std::{ffi::c_void, ptr::null_mut};

use magnus::Ruby;
use rb_sys::{
    rb_thread_call_with_gvl, rb_thread_call_without_gvl
};

pub fn call_without_gvl<F, R>(f: F) -> R
where
    F: FnOnce() -> R,
{
    extern "C" fn trampoline<F, R>(arg: *mut c_void) -> *mut c_void
    where
        F: FnOnce() -> R,
    {
        let closure_ptr = arg as *mut Option<F>;
        let closure = unsafe { (*closure_ptr).take().expect("Closure already taken") };

        let result = closure();

        let boxed_result = Box::new(result);
        Box::into_raw(boxed_result) as *mut c_void
    }

    let mut closure_opt = Some(f);
    let closure_ptr = &mut closure_opt as *mut Option<F> as *mut c_void;

    let raw_result_ptr = unsafe {
        rb_thread_call_without_gvl(
            Some(trampoline::<F, R>),
            closure_ptr,
            None,
            null_mut(),
        )
    };

    let result_box = unsafe { Box::from_raw(raw_result_ptr as *mut R) };
    *result_box
}

pub fn call_with_gvl<F, R>(f: F) -> R
where
    F: FnOnce(Ruby) -> R,
{
    extern "C" fn trampoline<F, R>(arg: *mut c_void) -> *mut c_void
    where
        F: FnOnce(Ruby) -> R,
    {
        let closure_ptr = arg as *mut Option<F>;
        let closure = unsafe { (*closure_ptr).take().expect("Closure already taken") };

        let result = closure(Ruby::get().unwrap());

        let boxed_result = Box::new(result);
        Box::into_raw(boxed_result) as *mut c_void
    }

    let mut closure_opt = Some(f);
    let closure_ptr = &mut closure_opt as *mut Option<F> as *mut c_void;

    let raw_result_ptr = unsafe { rb_thread_call_with_gvl(Some(trampoline::<F, R>), closure_ptr) };

    let result_box = unsafe { Box::from_raw(raw_result_ptr as *mut R) };
    *result_box
}
