The **Replace text.lua** script reads rules from text files to match and replace expressions, there are 2 ways to do so:

1-Via "Regular Expression (regex)" (see "re" module of aegisub for more informations) using the following method:
```
  %1 regex_match_expression  
  %2 regex_replace_expression
```  
  
  **Example**: subtitle line text = they should of...
  ```
  %1 (should|could)\s+of  
  %2 \1've
  ```
  
  after applying the above rule, the replaced text would be:   they **should've**...
  
  
2-Via "**Simple Match**":  **match_expression**+**replace_expression** with 2 cases:

  **a**-**match_expression** contains **no spaces**:


**Example**: subtitle line text = wich is wrong...


 `wich+which`


  after applying the above rule, the replaced text would be:   **which** is wrong...
    
	
  **b**-**match_expression** contains **spaces**:

  Suppose we have the following rules:

  **Rule1**:     
  `/aren't/'re not+are not`
	    
   **Example1**: they aren't here. -> they **are not** here.	    
   **Example2**: they're not here. -> they**are not** here.
	    
   **Rule2**:   
   `/should have+should've`

   **Example**: you should have seen it. -> you **should've** seen it.
	    

**Important remarks**:    (for both "**regex**" and "**Simple Match**" case)

1-you can add **%ask** after the **replace_expression**  to **confirm** (and possibly **edit**) the replacement text.  
  
2-if you add **%hint rule_description** after the **replace_expression** (and after **%ask** expression if it exists), the **rule_description** will be used as a description text in the replacements log dialog for the rule applied (otherwise the **replace_expression** is used).
	 
3-Lines that start with  **#** are treated as comments and thus ignonred (so is for empty lines).'
