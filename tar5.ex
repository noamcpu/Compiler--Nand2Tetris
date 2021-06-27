select (select LastName from Person p where p.personid = em.personid 
group by em.personid, p.Lastname having Exists(select personid from Employee))
As Last_Name_of_employee, (select FirstName from Person p where p.personid = em.personid 
group by em.personid, p.firstname having Exists(select personid from Employee))
As First_Name_of_employee, 
case when mod(to_number(em.personid), 100) >= 1 and mod(to_number(em.personid), 100) <= 15
     then 'servant' 
       when mod(to_number(em.personid), 100) >= 15 and mod(to_number(em.personid), 100) <= 26 then
'Baker' 
       when mod(to_number(em.personid), 100) = 27 then 'security' when mod(to_number(em.personid), 100)
          >= 28 and
mod(to_number(em.personid), 100) <= 30 then 'secertary' else 'acountant' END role_of_employee

from Employee em
group by em.personid, em.phone_number, em.address
having Exists(select address from Employee where address = em.address
group by em.address, address
having Length(em.address) >= 3 and address is not NULL) and Exists(select salary from 
employee group by salary having salary is not NULL) 
order by Last_Name_of_employee Desc, First_Name_of_employee DESC;


