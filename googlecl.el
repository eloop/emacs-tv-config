;;; googlecl.el - elisp UI for googlecl commands.

;;; Code:

(defun google-create-album (dir)
  (interactive (list (anything-c-read-file-name "Directory: "
                                                :test 'file-directory-p
                                                :initial-input "/home/thierry/Pictures/")))
  (lexical-let ((album (car (last (split-string dir "/"))))) 
    (start-process-shell-command
     "googlecl" nil
     (format "google picasa create --title %s %s*.jpg"
             album
             (file-name-as-directory dir)))
    (set-process-sentinel (get-process "googlecl")
                          #'(lambda (process event)
                              (when (string= event "finished\n")
                                (message "`%s' album synced to google." album))))))

(defvar gpicasa-album-list nil)
(defun google-update-album-list-db ()
  (setq gpicasa-album-list nil)
  (when (file-exists-p "~/.emacs.d/gpicasa-album-list.elc")
    (delete-file "~/.emacs.d/gpicasa-album-list.elc"))
  (lexical-let ((album-list ()))
    (start-process-shell-command "gpicasa-list" nil "google picasa list-albums")
    (set-process-filter (get-process "gpicasa-list")
                        #'(lambda (process output)
                            (setq album-list (cons output album-list))))
    (set-process-sentinel (get-process "gpicasa-list")
                          #'(lambda (process event)
                              (when (string= event "finished\n")
                                (loop for album in (split-string (car album-list) "\n" t)
                                   collect (split-string album ",") into ls-album
                                   finally do
                                   (progn
                                     (setq gpicasa-album-list ls-album)
                                     (dump-object-to-file 'gpicasa-album-list "~/.emacs.d/gpicasa-album-list.el"))))))))
                                       
(defun google-insert-link-to-album-at-point (arg)
  (interactive "P")
  (when arg (google-update-album-list-db))
  (while (not (file-exists-p "~/.emacs.d/gpicasa-album-list.elc")) (sit-for 0.1))
  (unless gpicasa-album-list (load-file "~/.emacs.d/gpicasa-album-list.elc"))
  (let ((album (anything-comp-read "Album: " gpicasa-album-list)))
    (insert (car album))))

(defun google-post-image-to-album (arg)
  (interactive "P")
  (when arg (google-update-album-list-db))
  (while (not (file-exists-p "~/.emacs.d/gpicasa-album-list.elc")) (sit-for 0.1))
  (unless gpicasa-album-list (load-file "~/.emacs.d/gpicasa-album-list.elc"))
  (lexical-let ((album (anything-comp-read "Album: " (loop for i in gpicasa-album-list collect (car i))))
                (file  (anything-c-read-file-name "File: " :initial-input "~/Pictures")))
    (start-process-shell-command
     "gpicasa-post" nil
     (format "google picasa post --src %s %s"
             (shell-quote-argument file)
             album))
    (set-process-sentinel (get-process "gpicasa-post")
                          #'(lambda (process event)
                              (when (string= event "finished\n")
                                (message "`%s' pushed to `%s'" file album))))))

(provide 'googlecl)

;;; googlecl.el ends here.